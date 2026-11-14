-- =====================================================================
-- Datos iniciales para el prototipo
-- Ejecutar después de nortfarma_db.sql
-- Boticas y productos no van aquí: vienen del sistema de Nortfarma (precarga_app.sql
-- y la sincronización diaria). Los usuarios se crean desde la app (necesitan uid de Firebase).
-- =====================================================================

USE nortfarma_db;

-- Roles (ids alfanuméricos según el diccionario de datos)
INSERT INTO Rol (id_rol, nombre) VALUES
  ('RL01', 'Administrador'),
  ('RL02', 'Encargado de botica'),
  ('RL03', 'Repartidor'),
  ('RL04', 'Cliente');

INSERT INTO Estado_Pago (id_estado_pago, nombre) VALUES
  (1, 'Pendiente'),
  (2, 'Aprobado'),
  (3, 'Fallido');

INSERT INTO Tipo_Pago (id_tipo_pago, nombre) VALUES
  (1, 'En línea (tarjeta)'),
  (2, 'Yape/Plin'),
  (3, 'Contraentrega POS'),
  (4, 'Contraentrega efectivo');

INSERT INTO Estado_Pedido (id_estado_pedido, nombre) VALUES
  (1, 'Procesando'),
  (2, 'Empaquetado'),
  (3, 'En camino'),
  (4, 'Listo para recoger'),
  (5, 'Entregado'),
  (6, 'Fallido');

-- Ubigeo (códigos INEI): distritos con delivery. El distrito que detecta Google Maps
-- en la app debe coincidir con uno de estos; si no, no se acepta la dirección.
INSERT INTO Ubigeo (id_ubigeo, departamento, provincia, distrito) VALUES
  ('200101', 'Piura', 'Piura', 'Piura'),
  ('200104', 'Piura', 'Piura', 'Castilla'),
  ('200115', 'Piura', 'Piura', 'Veintiséis de Octubre');

-- Categorías (las del diseño de la pantalla de Inicio)
INSERT INTO Categoria_App (id_categoria, nombre_visual, icono_url) VALUES
  (1, 'Medicinas',        'icono://medicinas'),
  (2, 'Dolor y fiebre',   'icono://dolor_fiebre'),
  (3, 'Vitaminas',        'icono://vitaminas'),
  (4, 'Cuidado personal', 'icono://cuidado_personal'),
  (5, 'Bebé',             'icono://bebe'),
  (6, 'Botiquín',         'icono://botiquin');
