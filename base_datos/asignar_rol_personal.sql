-- =====================================================================
-- Dar rol de personal a una cuenta (solo mientras no exista el panel del Administrador)
-- 1. La persona se registra en la app como cliente (queda con rol RL04).
-- 2. Ejecuta aquí la línea que corresponda, cambiando el correo.
-- 3. La persona cierra sesión y vuelve a entrar.
-- Roles: RL01 Administrador · RL02 Encargado de botica · RL03 Repartidor · RL04 Cliente
-- =====================================================================

USE nortfarma_db;

-- Encargado de botica (id_botica: 1 Centro, 2 Castilla, 3 Los Ejidos)
-- UPDATE Usuario SET id_rol = 'RL02', id_botica = 2 WHERE correo = 'correo@ejemplo.com';

-- Repartidor
-- UPDATE Usuario SET id_rol = 'RL03', id_botica = NULL WHERE correo = 'correo@ejemplo.com';

-- Administrador
-- UPDATE Usuario SET id_rol = 'RL01', id_botica = NULL WHERE correo = 'correo@ejemplo.com';

-- Ver usuarios y roles
SELECT u.id_usuario, u.correo, r.nombre AS rol, b.nombre AS botica
  FROM Usuario u
  JOIN Rol r ON r.id_rol = u.id_rol
  LEFT JOIN Botica b ON b.id_botica = u.id_botica
 ORDER BY u.id_usuario;
