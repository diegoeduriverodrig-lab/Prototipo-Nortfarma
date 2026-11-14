"""
Genera ../migracion_2026-10-16b.sql: carga las 52 boticas de la zona objetivo
(boticas_zona_piura.xlsx) en la base de la app SIN borrar pedidos ni usuarios.
- nortfarma_db.Botica: actualiza las boticas que ya existían (mismo código) e inserta las nuevas.
- La de delivery pasa a ser la F24 (Galería Country, junto al BCP).
- El encargado de prueba de Castilla pasa a la F43 (Urb. Miraflores, Castilla).
El sistema de Nortfarma (nortfarma_core) se recarga aparte con nortfarma_core.sql,
guardando antes sus ventas (ver el paso a paso al inicio del SQL generado).
"""
import sys
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
sys.path.insert(0, str(CARPETA))
from generar_core import leer_boticas, q  # noqa: E402

boticas = [b for b in leer_boticas() if b["latitud"] is not None]
lineas = [
    "-- =====================================================================",
    "-- Migración 2026-10-16 (b): boticas reales de la zona objetivo (52)",
    "-- Fuente: datos_origen/boticas_zona_piura.xlsx (Nortfarma) + coordenadas de OpenStreetMap.",
    "-- Generado por nortfarma_core/migrar_boticas_zona.py. Se ejecutó con root así:",
    "--   1. PARTE 1 (guarda las ventas del sistema de Nortfarma)",
    "--   2. nortfarma_core/nortfarma_core.sql (recarga boticas, stock, precios...)",
    "--   3. PARTE 2 (devuelve las ventas y actualiza las boticas de la app)",
    "-- =====================================================================",
    "",
    "-- PARTE 1 ---------------------------------------------------------------",
    "CREATE DATABASE IF NOT EXISTS migracion_tmp;",
    "DROP TABLE IF EXISTS migracion_tmp.venta, migracion_tmp.detalle_venta;",
    "CREATE TABLE migracion_tmp.venta AS SELECT * FROM nortfarma_core.venta;",
    "CREATE TABLE migracion_tmp.detalle_venta AS SELECT * FROM nortfarma_core.detalle_venta;",
    "",
    "-- PARTE 2 ---------------------------------------------------------------",
    "INSERT INTO nortfarma_core.venta SELECT * FROM migracion_tmp.venta;",
    "INSERT INTO nortfarma_core.detalle_venta SELECT * FROM migracion_tmp.detalle_venta;",
    "DROP DATABASE migracion_tmp;",
    "",
    "USE nortfarma_db;",
    "UPDATE Botica SET hace_delivery = FALSE;",
]
for b in boticas:
    valores = [b["botica_id"], b["nombre"], b["direccion"], b["departamento"], b["zona"], b["latitud"], b["longitud"],
               b["apertura_semana"], b["cierre_semana"], b["apertura_domingo"], b["cierre_domingo"], b["delivery"]]
    lineas.append(
        "INSERT INTO Botica (id_botica_core, nombre, direccion, departamento, zona, latitud, longitud, "
        "hora_apertura_semana, hora_cierre_semana, hora_apertura_domingo, hora_cierre_domingo, hace_delivery, "
        f"fecha_sincronizacion) VALUES ({', '.join(q(v) for v in valores)}, NOW())\n"
        "  ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), direccion = VALUES(direccion), "
        "departamento = VALUES(departamento), zona = VALUES(zona), latitud = VALUES(latitud), "
        "longitud = VALUES(longitud), hora_apertura_semana = VALUES(hora_apertura_semana), "
        "hora_cierre_semana = VALUES(hora_cierre_semana), hora_apertura_domingo = VALUES(hora_apertura_domingo), "
        "hora_cierre_domingo = VALUES(hora_cierre_domingo), hace_delivery = VALUES(hace_delivery), "
        "fecha_sincronizacion = NOW();")
lineas += [
    "",
    "-- El encargado de prueba de Castilla queda en una botica de Castilla.",
    "UPDATE Usuario SET id_botica = (SELECT id_botica FROM Botica WHERE id_botica_core = 'F43')",
    " WHERE correo = 'encargado.castilla@nortfarma.test';",
]
(CARPETA.parent / "migracion_2026-10-16b.sql").write_text("\n".join(lineas) + "\n", encoding="utf-8")
print(f"{len(boticas)} boticas")
