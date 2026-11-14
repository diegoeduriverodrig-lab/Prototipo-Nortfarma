-- =====================================================================
-- Migración del 2026-10-15 (cambios pedidos en "NORTFARMA SISTEMA Y PREGUNTAS")
-- Se ejecutó una sola vez, con el usuario root, en este orden:
--   1. migracion_2026-10-15.sql  -> PARTE 1 (guarda usuarios y direcciones)
--   2. nortfarma_db.sql, datos_iniciales.sql, precarga_app.sql (estructura nueva)
--   3. migracion_2026-10-15.sql  -> PARTE 2 (devuelve usuarios y direcciones)
--   4. nortfarma_core/nortfarma_core.sql (sistema de Nortfarma simulado)
-- Los pedidos de prueba anteriores NO se migraron (usaban productos y boticas que
-- ya no existen). Están en respaldo_2026-10-15_antes_de_cambios.sql.
-- =====================================================================

-- PARTE 1 ---------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS migracion_tmp;
DROP TABLE IF EXISTS migracion_tmp.Usuario, migracion_tmp.Direccion_Cliente;
CREATE TABLE migracion_tmp.Usuario AS SELECT * FROM nortfarma_db.Usuario;
CREATE TABLE migracion_tmp.Direccion_Cliente AS SELECT * FROM nortfarma_db.Direccion_Cliente;
DROP DATABASE nortfarma_db;

-- PARTE 2 ---------------------------------------------------------------
-- Las boticas de prueba anteriores (1, 2, 3) pasan a sus equivalentes de Nortfarma.
INSERT INTO nortfarma_db.Usuario (id_usuario, uid_firebase, id_rol, id_botica, nombre, apellido, dni, telefono, correo)
SELECT u.id_usuario, u.uid_firebase, u.id_rol,
       (SELECT b.id_botica FROM nortfarma_db.Botica b
         WHERE b.id_botica_core = CASE u.id_botica WHEN 1 THEN 'CEN' WHEN 2 THEN 'F44' WHEN 3 THEN 'F35' END),
       u.nombre, u.apellido, u.dni, u.telefono, u.correo
  FROM migracion_tmp.Usuario u;

INSERT INTO nortfarma_db.Direccion_Cliente
SELECT * FROM migracion_tmp.Direccion_Cliente;

DROP DATABASE migracion_tmp;

-- Usuario de MySQL del "sistema de Nortfarma" (solo accede a nortfarma_core).
CREATE USER IF NOT EXISTS 'nortfarma_core_app'@'localhost' IDENTIFIED BY 'CoreNortfarma2026!';
CREATE USER IF NOT EXISTS 'nortfarma_core_app'@'127.0.0.1' IDENTIFIED BY 'CoreNortfarma2026!';
GRANT SELECT, INSERT, UPDATE, DELETE ON nortfarma_core.* TO 'nortfarma_core_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON nortfarma_core.* TO 'nortfarma_core_app'@'127.0.0.1';
