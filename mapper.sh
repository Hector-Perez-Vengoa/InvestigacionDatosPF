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
