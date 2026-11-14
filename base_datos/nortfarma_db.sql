-- =====================================================================
-- Base de datos de la aplicación de pedidos en línea
-- Boticas Felicidad - Nortfarma S.A.C.
-- Motor: MySQL 8 · InnoDB · utf8mb4
-- Orden: catálogos -> usuarios y direcciones -> productos -> transaccionales
-- Boticas y productos son una copia del sistema de Nortfarma (nortfarma_core),
-- que se actualiza a diario; precio, descuento y stock se consultan en tiempo real.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS nortfarma_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE nortfarma_db;

-- ---------------------------------------------------------------------
-- Tablas maestras / catálogos
-- ---------------------------------------------------------------------

CREATE TABLE Rol (
  id_rol  CHAR(4)     NOT NULL,
  nombre  VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_rol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Ubigeo (
  id_ubigeo     VARCHAR(6)  NOT NULL,
  departamento  VARCHAR(50) NOT NULL,
  provincia     VARCHAR(50) NOT NULL,
  distrito      VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_ubigeo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Estado_Pago (
  id_estado_pago  INT         NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_estado_pago)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Tipo_Pago (
  id_tipo_pago  INT         NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_tipo_pago)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Estado_Pedido (
  id_estado_pedido  INT         NOT NULL AUTO_INCREMENT,
  nombre            VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_estado_pedido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Copia diaria de las boticas del sistema de Nortfarma (solo las que tienen ubicación).
-- Todas permiten recojo en tienda; una sola (hace_delivery) despacha los deliverys.
CREATE TABLE Botica (
  id_botica              INT            NOT NULL AUTO_INCREMENT,
  id_botica_core         VARCHAR(10)    NOT NULL,  -- código en el sistema de Nortfarma (CEN, F14...)
  nombre                 VARCHAR(150)   NOT NULL,
  direccion              VARCHAR(255)   NOT NULL,
  departamento           VARCHAR(50)    NOT NULL,
  zona                   VARCHAR(50)    NOT NULL,
  latitud                DECIMAL(10,8)  NOT NULL,
  longitud               DECIMAL(10,8)  NOT NULL,
  hora_apertura_semana   TIME           NULL,      -- lunes a sábado
  hora_cierre_semana     TIME           NULL,
  hora_apertura_domingo  TIME           NULL,      -- domingos y feriados; NULL = no abre
  hora_cierre_domingo    TIME           NULL,
  hace_delivery          BOOLEAN        NOT NULL DEFAULT FALSE,  -- la decide la app (no viene de Nortfarma): despacha los deliverys
  fecha_sincronizacion   DATETIME       NOT NULL,
  PRIMARY KEY (id_botica),
  UNIQUE KEY uq_botica_core (id_botica_core)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Categoria_App (
  id_categoria   INT           NOT NULL AUTO_INCREMENT,
  nombre_visual  VARCHAR(100)  NOT NULL,
  icono_url      VARCHAR(255)  NOT NULL,
  activa         BOOLEAN       NOT NULL DEFAULT TRUE,  -- FALSE = oculta para el cliente (no se borra)
  PRIMARY KEY (id_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Usuarios y direcciones
-- ---------------------------------------------------------------------

-- La contraseña la gestiona Firebase Authentication; aquí solo se guarda su uid.
CREATE TABLE Usuario (
  id_usuario    INT           NOT NULL AUTO_INCREMENT,
  uid_firebase  VARCHAR(128)  NOT NULL,
  id_rol        CHAR(4)       NOT NULL,
  id_botica     INT           NULL,      -- solo para el Encargado de botica
  nombre        VARCHAR(100)  NOT NULL,
  apellido      VARCHAR(100)  NOT NULL,
  dni           VARCHAR(15)   NOT NULL,
  telefono      VARCHAR(20)   NOT NULL,
  correo        VARCHAR(150)  NOT NULL,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uq_usuario_uid (uid_firebase),
  UNIQUE KEY uq_usuario_correo (correo),
  UNIQUE KEY uq_usuario_dni (dni),
  CONSTRAINT fk_usuario_rol    FOREIGN KEY (id_rol)    REFERENCES Rol (id_rol),
  CONSTRAINT fk_usuario_botica FOREIGN KEY (id_botica) REFERENCES Botica (id_botica)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Direccion_Cliente (
  id_direccion      INT            NOT NULL AUTO_INCREMENT,
  id_usuario        INT            NOT NULL,
  id_ubigeo         VARCHAR(6)     NOT NULL,
  direccion_exacta  VARCHAR(255)   NOT NULL,
  referencia        VARCHAR(255)   NULL,
  latitud           DECIMAL(10,8)  NOT NULL,
  longitud          DECIMAL(10,8)  NOT NULL,
  PRIMARY KEY (id_direccion),
  CONSTRAINT fk_direccion_usuario FOREIGN KEY (id_usuario) REFERENCES Usuario (id_usuario),
  CONSTRAINT fk_direccion_ubigeo  FOREIGN KEY (id_ubigeo)  REFERENCES Ubigeo (id_ubigeo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Productos
-- ---------------------------------------------------------------------

-- Copia diaria de los productos del sistema de Nortfarma.
-- Precio, descuento y stock NO se guardan: se consultan en tiempo real.
-- Presentaciones: empaque (siempre), blíster y fracción (unidad) si se venden así.
CREATE TABLE Producto_App (
  id_producto           INT           NOT NULL AUTO_INCREMENT,
  id_producto_core      VARCHAR(20)   NOT NULL,  -- referencia en el sistema de Nortfarma
  id_categoria          INT           NULL,      -- la pone el Administrador; NULL = producto nuevo sin clasificar
  nombre_comercial      VARCHAR(500)  NOT NULL,  -- nombre en Nortfarma (lo actualiza la sincronización)
  nombre_app            VARCHAR(150)  NULL,      -- nombre que ve el cliente; NULL = se muestra nombre_comercial
  especificaciones      TEXT          NOT NULL,
  empaque               VARCHAR(60)   NOT NULL,  -- ej. 'Caja x 100 tabletas'
  unidades_empaque      INT           NOT NULL,
  se_vende_blister      BOOLEAN       NOT NULL,
  unidades_blister      INT           NULL,
  se_vende_fraccion     BOOLEAN       NOT NULL,
  apto_ecommerce        BOOLEAN       NOT NULL,  -- lo decide el Administrador
  requiere_receta       BOOLEAN       NOT NULL,
  fecha_sincronizacion  DATETIME      NOT NULL,
  PRIMARY KEY (id_producto),
  UNIQUE KEY uq_producto_core (id_producto_core),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES Categoria_App (id_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Imagen_Producto (
  id_imagen     INT           NOT NULL AUTO_INCREMENT,
  id_producto   INT           NOT NULL,
  url_imagen    VARCHAR(255)  NOT NULL,
  es_principal  BOOLEAN       NOT NULL,
  PRIMARY KEY (id_imagen),
  CONSTRAINT fk_imagen_producto FOREIGN KEY (id_producto) REFERENCES Producto_App (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Transaccionales: pedidos y pagos
-- ---------------------------------------------------------------------

CREATE TABLE Pedido (
  id_pedido         INT            NOT NULL AUTO_INCREMENT,
  id_cliente        INT            NOT NULL,
  id_repartidor     INT            NULL,      -- nulo si es retiro en botica
  id_botica         INT            NULL,      -- nulo si es delivery
  id_direccion      INT            NULL,      -- nulo si es retiro en botica
  id_estado_pedido  INT            NOT NULL,
  id_tipo_pago      INT            NOT NULL,
  tipo_entrega      VARCHAR(20)    NOT NULL,  -- 'Delivery' o 'Retiro en Botica'
  tipo_comprobante  VARCHAR(20)    NOT NULL,  -- 'Boleta' o 'Factura'
  ruc_facturacion   VARCHAR(20)    NULL,      -- obligatorio solo si es factura
  razon_social      VARCHAR(150)   NULL,      -- obligatorio solo si es factura
  costo_envio       DECIMAL(10,2)  NOT NULL DEFAULT 0.00,  -- 0 si es retiro en botica
  codigo_promocion  VARCHAR(30)    NULL,
  monto_total       DECIMAL(10,2)  NOT NULL,  -- productos (con descuento) + envío
  id_venta_core      INT           NULL,      -- venta registrada en el sistema de Nortfarma
  numero_comprobante VARCHAR(20)   NULL,      -- comprobante que asigna Nortfarma (V0001, V0002...)
  fecha_pedido      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pedido),
  CONSTRAINT fk_pedido_cliente     FOREIGN KEY (id_cliente)       REFERENCES Usuario (id_usuario),
  CONSTRAINT fk_pedido_repartidor  FOREIGN KEY (id_repartidor)    REFERENCES Usuario (id_usuario),
  CONSTRAINT fk_pedido_botica      FOREIGN KEY (id_botica)        REFERENCES Botica (id_botica),
  CONSTRAINT fk_pedido_direccion   FOREIGN KEY (id_direccion)     REFERENCES Direccion_Cliente (id_direccion),
  CONSTRAINT fk_pedido_estado      FOREIGN KEY (id_estado_pedido) REFERENCES Estado_Pedido (id_estado_pedido),
  CONSTRAINT fk_pedido_tipo_pago   FOREIGN KEY (id_tipo_pago)     REFERENCES Tipo_Pago (id_tipo_pago)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Precio y nombre se copian al registrar el pedido y ya no cambian (histórico).
CREATE TABLE Detalle_Pedido (
  id_detalle           INT            NOT NULL AUTO_INCREMENT,
  id_pedido            INT            NOT NULL,
  id_producto          INT            NOT NULL,
  presentacion         VARCHAR(10)    NOT NULL,  -- 'EMPAQUE', 'BLISTER' o 'FRACCION'
  cantidad             INT            NOT NULL,  -- cantidad de esa presentación
  precio_historico     DECIMAL(10,2)  NOT NULL,  -- precio UNITARIO pagado (ya con descuento)
  descuento_historico  DECIMAL(5,2)   NOT NULL DEFAULT 0,  -- % de descuento aplicado
  id_precio_core       INT            NULL,      -- id del precio en el sistema de Nortfarma
  nombre_historico     VARCHAR(150)   NOT NULL,
  PRIMARY KEY (id_detalle),
  CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES Pedido (id_pedido),
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES Producto_App (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Foto de la receta médica que adjunta el cliente (no se valida en la app).
CREATE TABLE Receta (
  id_receta    INT           NOT NULL AUTO_INCREMENT,
  id_pedido    INT           NOT NULL,
  imagen_url   VARCHAR(255)  NOT NULL,
  fecha_carga  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_receta),
  CONSTRAINT fk_receta_pedido FOREIGN KEY (id_pedido) REFERENCES Pedido (id_pedido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE Pago (
  id_pago            INT            NOT NULL AUTO_INCREMENT,
  id_pedido          INT            NOT NULL,
  id_tipo_pago       INT            NOT NULL,
  id_estado_pago     INT            NOT NULL,
  monto_procesado    DECIMAL(10,2)  NOT NULL,  -- se copia de Pedido.monto_total
  pasarela           VARCHAR(50)    NULL,
  token_transaccion  VARCHAR(255)   NOT NULL,  -- id del cargo que devuelve Culqi (chr_...)
  fecha_pago         DATETIME       NOT NULL,
  PRIMARY KEY (id_pago),
  CONSTRAINT fk_pago_pedido     FOREIGN KEY (id_pedido)      REFERENCES Pedido (id_pedido),
  CONSTRAINT fk_pago_tipo_pago  FOREIGN KEY (id_tipo_pago)   REFERENCES Tipo_Pago (id_tipo_pago),
  CONSTRAINT fk_pago_estado     FOREIGN KEY (id_estado_pago) REFERENCES Estado_Pago (id_estado_pago)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cada cambio de estado del pedido con su fecha, quién lo hizo y el motivo
-- (por ejemplo, el motivo de una entrega fallida). Sirve para medir el servicio.
CREATE TABLE Historial_Estado_Pedido (
  id_historial      INT           NOT NULL AUTO_INCREMENT,
  id_pedido         INT           NOT NULL,
  id_estado_pedido  INT           NOT NULL,
  id_usuario        INT           NULL,      -- quién cambió el estado (nulo si fue el sistema)
  motivo            VARCHAR(255)  NULL,
  fecha_cambio      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_historial),
  CONSTRAINT fk_historial_pedido  FOREIGN KEY (id_pedido)        REFERENCES Pedido (id_pedido),
  CONSTRAINT fk_historial_estado  FOREIGN KEY (id_estado_pedido) REFERENCES Estado_Pedido (id_estado_pedido),
  CONSTRAINT fk_historial_usuario FOREIGN KEY (id_usuario)       REFERENCES Usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Datos de la entrega a domicilio (una fila por pedido delivery con repartidor)
CREATE TABLE Entrega (
  id_entrega        INT            NOT NULL AUTO_INCREMENT,
  id_pedido         INT            NOT NULL,
  id_repartidor     INT            NOT NULL,
  fecha_asignacion  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_salida      DATETIME       NULL,      -- el repartidor inicia la entrega (En camino)
  fecha_entrega     DATETIME       NULL,      -- el cliente recibe el pedido (Entregado)
  evidencia_url     VARCHAR(255)   NULL,      -- foto de la entrega (evidencias/<id>.jpg)
  latitud_entrega   DECIMAL(10,8)  NULL,      -- ubicación GPS del repartidor al entregar
  longitud_entrega  DECIMAL(10,8)  NULL,
  observacion       VARCHAR(255)   NULL,
  PRIMARY KEY (id_entrega),
  UNIQUE KEY uq_entrega_pedido (id_pedido),
  CONSTRAINT fk_entrega_pedido     FOREIGN KEY (id_pedido)     REFERENCES Pedido (id_pedido),
  CONSTRAINT fk_entrega_repartidor FOREIGN KEY (id_repartidor) REFERENCES Usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Problemas durante la entrega: los que la hacen fallar y los que no (retrasos, etc.)
CREATE TABLE Incidencia_Entrega (
  id_incidencia  INT           NOT NULL AUTO_INCREMENT,
  id_entrega     INT           NOT NULL,
  tipo           VARCHAR(60)   NOT NULL,
  detalle        VARCHAR(255)  NULL,
  termina_entrega BOOLEAN       NOT NULL DEFAULT FALSE,  -- TRUE si la entrega se marcó como fallida
  fecha          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_incidencia),
  CONSTRAINT fk_incidencia_entrega FOREIGN KEY (id_entrega) REFERENCES Entrega (id_entrega)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
