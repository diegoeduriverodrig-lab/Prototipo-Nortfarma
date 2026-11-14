-- =====================================================================
-- Migración del 2026-10-16 (información pendiente que entregó el equipo)
-- - Zona: solo Piura, Castilla y Veintiséis de Octubre (sale Catacaos).
-- - Boticas reales; todos los deliverys salen de la de Av. Country (junto al BCP).
-- - Tipo de receta según DIGEMID.
-- - Comprobante: V + 4 dígitos (V0001).
-- Se ejecutó una sola vez, con root, en este orden:
--   1. PARTE 1 de este archivo (guarda usuarios y direcciones)
--   2. nortfarma_db.sql, datos_iniciales.sql, precarga_app.sql
--   3. PARTE 2 de este archivo (devuelve usuarios y direcciones)
--   4. nortfarma_core/nortfarma_core.sql
-- Los pedidos de prueba anteriores no se migraron: están en respaldo_2026-10-16_antes_de_cambios.sql.
-- =====================================================================

-- PARTE 1 ---------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS migracion_tmp;
DROP TABLE IF EXISTS migracion_tmp.Usuario, migracion_tmp.Direccion_Cliente, migracion_tmp.Botica;
CREATE TABLE migracion_tmp.Usuario AS SELECT * FROM nortfarma_db.Usuario;
CREATE TABLE migracion_tmp.Direccion_Cliente AS SELECT * FROM nortfarma_db.Direccion_Cliente WHERE id_ubigeo <> '200105';
CREATE TABLE migracion_tmp.Botica AS SELECT id_botica, id_botica_core FROM nortfarma_db.Botica;
DROP DATABASE nortfarma_db;

-- PARTE 2 ---------------------------------------------------------------
-- El encargado conserva su botica (por código de Nortfarma).
INSERT INTO nortfarma_db.Usuario (id_usuario, uid_firebase, id_rol, id_botica, nombre, apellido, dni, telefono, correo)
SELECT u.id_usuario, u.uid_firebase, u.id_rol,
       (SELECT nb.id_botica FROM nortfarma_db.Botica nb JOIN migracion_tmp.Botica ob ON ob.id_botica_core = nb.id_botica_core
         WHERE ob.id_botica = u.id_botica),
       u.nombre, u.apellido, u.dni, u.telefono, u.correo
  FROM migracion_tmp.Usuario u;

INSERT INTO nortfarma_db.Direccion_Cliente SELECT * FROM migracion_tmp.Direccion_Cliente;

DROP DATABASE migracion_tmp;
