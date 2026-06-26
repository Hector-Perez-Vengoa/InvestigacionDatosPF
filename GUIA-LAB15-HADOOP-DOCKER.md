# Laboratorio 15 — Apache Hadoop con Docker Compose

## 0. Objetivo del laboratorio

Instalar y configurar un clúster Hadoop (HDFS + YARN + MapReduce) usando Docker, demostrar que funciona con un job real, y usarlo para analizar un dataset real de agroindustria (producción/venta en toneladas por actividad productiva, fuente: PNDA/PCM).

## 1. Qué se entrega al final

- PDF con capturas de pantalla de cada paso (comandos + resultados).
- El código usado: `docker-compose.yml`, `hadoop.env`, `mapper.sh`, `reducer.sh`.

## 2. Rúbrica — qué evidencia cubre cada criterio

| Criterio | Evidencia que lo cubre |
|---|---|
| Instalación y Configuración de Hadoop | Captura de `docker ps` + UIs web (9870 y 8088) |
| Comprensión de la Arquitectura Distribuida | Explicación de HDFS/YARN/MapReduce (sección 9) |
| Análisis de Aplicabilidad en Datos Masivos | Job MapReduce sobre el dataset real de agroindustria |
| Reflexión Crítica / Desarrollo Sostenible | Texto de reflexión (sección 9) |

---

## 3. Requisitos previos (instalar Docker)

### Windows / Mac
1. Descargar **Docker Desktop**: https://www.docker.com/products/docker-desktop/
2. Instalar y reiniciar el equipo si lo pide.
3. **Abrir Docker Desktop manualmente** y esperar a que el ícono de la ballena 🐳 deje de animarse (debe decir "Docker Desktop is running"). En Windows, si pide habilitar WSL2, aceptar.
4. Verificar en una terminal (PowerShell, CMD o terminal de Mac):
   ```bash
   docker --version
   docker compose version
   ```

### Linux
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install docker.io docker-compose-plugin -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # cerrar sesión y volver a entrar después de esto
```
Verificar:
```bash
docker --version
docker compose version
```

> ⚠️ Si al correr `docker compose up -d` sale un error como `open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified`, significa que Docker Desktop **no está abierto**. Ábrelo y espera a que cargue por completo antes de reintentar.

---

## 4. Crear la carpeta del proyecto

```bash
mkdir lab15-hadoop
cd lab15-hadoop
```

Dentro de esta carpeta deben quedar estos 5 archivos (se entregan junto con esta guía):

- `docker-compose.yml`
- `hadoop.env`
- `mapper.sh`
- `reducer.sh`
- `agroindustria_dataset_publicacion_2025_2026_pnda_pcm_sgtd.csv` (el dataset)

### Contenido de `docker-compose.yml`
```yaml
services:
  namenode:
    image: bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8
    container_name: namenode
    restart: always
    ports:
      - "9870:9870"
      - "9000:9000"
    volumes:
      - hadoop_namenode:/hadoop/dfs/name
    environment:
      - CLUSTER_NAME=test
    env_file:
      - ./hadoop.env

  datanode:
    image: bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8
    container_name: datanode
    restart: always
    volumes:
      - hadoop_datanode:/hadoop/dfs/data
    environment:
      SERVICE_PRECONDITION: "namenode:9870"
    env_file:
      - ./hadoop.env
    ports:
      - "9864:9864"

  resourcemanager:
    image: bde2020/hadoop-resourcemanager:2.0.0-hadoop3.2.1-java8
    container_name: resourcemanager
    restart: always
    environment:
      SERVICE_PRECONDITION: "namenode:9000 namenode:9870 datanode:9864"
    env_file:
      - ./hadoop.env
    ports:
      - "8088:8088"

  nodemanager:
    image: bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8
    container_name: nodemanager
    restart: always
    environment:
      SERVICE_PRECONDITION: "namenode:9000 namenode:9870 datanode:9864 resourcemanager:8088"
    env_file:
      - ./hadoop.env
    ports:
      - "8042:8042"

  historyserver:
    image: bde2020/hadoop-historyserver:2.0.0-hadoop3.2.1-java8
    container_name: historyserver
    restart: always
    environment:
      SERVICE_PRECONDITION: "namenode:9000 namenode:9870 datanode:9864 resourcemanager:8088"
    volumes:
      - hadoop_historyserver:/hadoop/yarn/timeline
    env_file:
      - ./hadoop.env
    ports:
      - "8188:8188"

volumes:
  hadoop_namenode:
  hadoop_datanode:
  hadoop_historyserver:
```

### Contenido de `hadoop.env`
```env
CORE_CONF_fs_defaultFS=hdfs://namenode:9000
CORE_CONF_hadoop_http_staticuser_user=root
CORE_CONF_hadoop_proxyuser_hue_hosts=*
CORE_CONF_hadoop_proxyuser_hue_groups=*
CORE_CONF_io_compression_codecs=org.apache.hadoop.io.compress.SnappyCodec

HDFS_CONF_dfs_webhdfs_enabled=true
HDFS_CONF_dfs_permissions_enabled=false
HDFS_CONF_dfs_namenode_datanode_registration_ip___hostname___check=false

YARN_CONF_yarn_log___aggregation___enable=true
YARN_CONF_yarn_log_server_url=http://historyserver:8188/applicationhistory/logs/
YARN_CONF_yarn_resourcemanager_recovery_enabled=true
YARN_CONF_yarn_resourcemanager_store_class=org.apache.hadoop.yarn.server.resourcemanager.recovery.FileSystemRMStateStore
YARN_CONF_yarn_resourcemanager_scheduler_class=org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler
YARN_CONF_yarn_scheduler_capacity_root_default_maximum___allocation___mb=8192
YARN_CONF_yarn_scheduler_capacity_root_default_maximum___allocation___vcores=4
YARN_CONF_yarn_resourcemanager_fs_state___store_uri=/rmstate
YARN_CONF_yarn_nodemanager_aux___services=mapreduce_shuffle
YARN_CONF_yarn_nodemanager_aux___services_mapreduce___shuffle_class=org.apache.hadoop.mapred.ShuffleHandler
YARN_CONF_yarn_resourcemanager_address=resourcemanager:8032
YARN_CONF_yarn_resourcemanager_scheduler_address=resourcemanager:8030
YARN_CONF_yarn_resourcemanager_resource__tracker_address=resourcemanager:8031

MAPRED_CONF_mapreduce_framework_name=yarn
MAPRED_CONF_mapred_child_java_opts=-Xmx4096m
MAPRED_CONF_mapreduce_map_memory_mb=4096
MAPRED_CONF_mapreduce_reduce_memory_mb=8192
MAPRED_CONF_mapreduce_map_java_opts=-Xmx3072m
MAPRED_CONF_mapreduce_reduce_java_opts=-Xmx6144m
MAPRED_CONF_yarn_app_mapreduce_am_env=HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1/
MAPRED_CONF_mapreduce_map_env=HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1/
MAPRED_CONF_mapreduce_reduce_env=HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1/
```

### Contenido de `mapper.sh`
```bash
#!/usr/bin/awk -f
BEGIN { FS=";" }
{
  gsub(/\r/, "")
  if ($4 != "actividad_productiva" && $9 != "") {
    val = $9
    gsub(",", "", val)
    print $4"\t"val
  }
}
```

### Contenido de `reducer.sh`
```bash
#!/usr/bin/awk -f
BEGIN { FS="\t" }
{
  sum[$1] += $2
}
END {
  for (k in sum) print k"\t"sum[k]
}
```

> El dataset CSV usa `;` como separador y `,` como separador de miles (ej. `5,806.850`). El mapper extrae la columna 4 (`actividad_productiva`) y la columna 9 (`produccion_tn`); el reducer suma toneladas producidas por actividad.

---

## 5. Levantar el clúster

```bash
docker compose up -d
```

Espera 30–60 segundos. Verifica que los 5 contenedores estén corriendo:
```bash
docker ps
```
Debes ver `namenode`, `datanode`, `resourcemanager`, `nodemanager`, `historyserver`, todos en estado `Up`.

📸 **Captura esta salida** (evidencia de "Instalación y Configuración").

Si algún contenedor no aparece o dice "Restarting":
```bash
docker logs <nombre_del_contenedor>
```
y revisa el error.

---

## 6. Verificar las interfaces web

- NameNode / HDFS: http://localhost:9870
- YARN ResourceManager: http://localhost:8088

📸 Captura ambas páginas cargando correctamente.

---

## 7. Probar HDFS

```bash
docker exec -it namenode hadoop fs -mkdir -p /user/root
docker exec -it namenode hadoop fs -ls /
```
📸 Captura el resultado.

---

## 8. Cargar el dataset y ejecutar el job MapReduce

### 8.1 Copiar archivos al contenedor `namenode`
```bash
docker cp agroindustria_dataset_publicacion_2025_2026_pnda_pcm_sgtd.csv namenode:/tmp/agro.csv
docker cp mapper.sh namenode:/tmp/mapper.sh
docker cp reducer.sh namenode:/tmp/reducer.sh
docker exec -it namenode chmod +x /tmp/mapper.sh /tmp/reducer.sh
```

### 8.2 Subir el dataset a HDFS
```bash
docker exec -it namenode hadoop fs -mkdir -p /user/root/agro/input
docker exec -it namenode hadoop fs -put /tmp/agro.csv /user/root/agro/input/
docker exec -it namenode hadoop fs -ls /user/root/agro/input
```
📸 Captura.

### 8.3 Ejecutar el job (Hadoop Streaming)
```bash
docker exec -it namenode bash -c "cd /tmp && hadoop jar /opt/hadoop-3.2.1/share/hadoop/tools/lib/hadoop-streaming-3.2.1.jar -files /tmp/mapper.sh,/tmp/reducer.sh -input /user/root/agro/input -output /user/root/agro/output -mapper mapper.sh -reducer reducer.sh"
```
📸 Captura toda la salida (logs de YARN: map 100%, reduce 100%, "completed successfully").

### 8.4 Ver el resultado
```bash
docker exec -it namenode hadoop fs -cat /user/root/agro/output/part-00000
```
Esto muestra el total de toneladas producidas por actividad productiva.
📸 Captura.

### 8.5 (Opcional) Verificar el job como SUCCEEDED en la UI de YARN
http://localhost:8088 → buscar el job en estado "SUCCEEDED".
📸 Captura.

---

## 9. Redactar el PDF final (estructura sugerida)

1. **Instalación y Configuración de Hadoop**
   - Capturas de los pasos 5, 6 y 7.
   - Breve explicación: se usó Docker Compose con las imágenes `bde2020/hadoop-*` para levantar un clúster pseudo-distribuido (NameNode, DataNode, ResourceManager, NodeManager, HistoryServer).

2. **Comprensión de la Arquitectura Distribuida de Hadoop**
   - HDFS: almacenamiento distribuido, divide archivos en bloques replicados entre DataNodes; el NameNode mantiene los metadatos.
   - YARN: gestiona los recursos del clúster (CPU/memoria) y la planificación de tareas; el ResourceManager asigna trabajo a los NodeManagers.
   - MapReduce: modelo de procesamiento paralelo en dos fases (Map y Reduce) que se ejecuta sobre los datos almacenados en HDFS, coordinado por YARN.
   - Explicar cómo interactúan: el cliente sube datos a HDFS → YARN asigna contenedores en los NodeManagers → las tareas Map/Reduce leen/escriben en HDFS.

3. **Análisis de la Aplicabilidad en Procesamiento de Datos Masivos**
   - Capturas del paso 8 (job real sobre el dataset de agroindustria).
   - Explicar qué se hizo: sumar toneladas producidas por actividad productiva usando un mapper/reducer en `awk` vía Hadoop Streaming.
   - Justificar por qué Hadoop frente a otras alternativas: para datasets pequeños (como este, ~1,500 filas) una hoja de cálculo o SQL es suficiente, pero el mismo pipeline escala sin cambios a millones/billones de registros distribuidos en muchos nodos, que es donde Hadoop justifica su uso (procesamiento distribuido, tolerancia a fallos, almacenamiento horizontal).

4. **Reflexión Crítica sobre el Impacto en el Desarrollo Sostenible**
   - Vincular Big Data/Hadoop con: optimización de cadenas agroindustriales (reducir desperdicio de producción), toma de decisiones públicas (PNDA/PCM) basada en datos reales, eficiencia energética de clústeres distribuidos.
   - Mencionar también un desafío ético/social: privacidad de datos, sesgos en datasets públicos, consumo energético de los centros de datos.

---

## 10. Apagar el clúster (al terminar)

```bash
docker compose down -v
```
El flag `-v` borra los volúmenes (todos los datos del HDFS simulado). Si quieren conservar los datos para seguir trabajando después, usar solo `docker compose down` (sin `-v`).

---

## 11. Solución de problemas comunes

| Error | Causa | Solución |
|---|---|---|
| `the attribute version is obsolete` | El campo `version` en el yml ya no se usa | Ignorar, es solo un warning (ya está removido en el archivo entregado) |
| `open //./pipe/dockerDesktopLinuxEngine...` | Docker Desktop no está abierto/corriendo | Abrir Docker Desktop y esperar que cargue antes de correr `docker compose up -d` |
| Algún contenedor en estado "Restarting" | Conflicto de puertos o memoria insuficiente | `docker logs <contenedor>` para ver el error; cerrar otras apps que usen los mismos puertos (9870, 8088, etc.) |
| El job de MapReduce no encuentra `awk` | Imagen del contenedor no trae `awk` | Avisar — se puede reescribir el mapper/reducer en Python |
