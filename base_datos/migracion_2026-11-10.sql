-- =====================================================================
-- Migración 2026-11-10: mejoras del catálogo y de las entregas
--   1. Categorías administrables: se pueden ocultar (Categoria_App.activa).
--   3. Nombre en la app: nombre que ve el cliente; la sincronización no lo toca.
--   5. Evidencia de entrega: tablas Entrega e Incidencia_Entrega.
-- (Las mejoras 2 y 4 no cambian la estructura: fotos subidas y carga de nombres.)
-- Se puede ejecutar una sola vez sobre una base existente; no borra datos.
-- =====================================================================

USE nortfarma_db;

-- 1. Categorías: ocultar en lugar de borrar
ALTER TABLE Categoria_App
  ADD COLUMN activa BOOLEAN NOT NULL DEFAULT TRUE AFTER icono_url;

-- 3. Nombre comercial propio de la app (NULL = se muestra el nombre de Nortfarma)
ALTER TABLE Producto_App
  ADD COLUMN nombre_app VARCHAR(150) NULL AFTER nombre_comercial;

-- 5. Datos de la entrega a domicilio (una fila por pedido delivery con repartidor)
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

-- Entregas anteriores a esta migración: se arman desde el historial de estados.
INSERT INTO Entrega (id_pedido, id_repartidor, fecha_asignacion, fecha_salida, fecha_entrega)
SELECT p.id_pedido, p.id_repartidor,
       COALESCE((SELECT MIN(h.fecha_cambio) FROM Historial_Estado_Pedido h
                  WHERE h.id_pedido = p.id_pedido AND h.motivo LIKE 'Repartidor asignado%'), p.fecha_pedido),
       (SELECT MIN(h.fecha_cambio) FROM Historial_Estado_Pedido h
         WHERE h.id_pedido = p.id_pedido AND h.id_estado_pedido = 3),
       (SELECT MIN(h.fecha_cambio) FROM Historial_Estado_Pedido h
         WHERE h.id_pedido = p.id_pedido AND h.id_estado_pedido = 5)
  FROM Pedido p
 WHERE p.tipo_entrega = 'Delivery' AND p.id_repartidor IS NOT NULL;

-- Entregas fallidas anteriores: su motivo pasa a ser una incidencia.
INSERT INTO Incidencia_Entrega (id_entrega, tipo, detalle, termina_entrega, fecha)
SELECT e.id_entrega, LEFT(SUBSTRING_INDEX(h.motivo, ': ', 1), 60),
       NULLIF(SUBSTRING(h.motivo, LENGTH(SUBSTRING_INDEX(h.motivo, ': ', 1)) + 3), ''), TRUE, h.fecha_cambio
  FROM Entrega e
  JOIN Historial_Estado_Pedido h ON h.id_pedido = e.id_pedido AND h.id_estado_pedido = 6
 WHERE h.motivo IS NOT NULL AND h.motivo NOT LIKE 'Pago devuelto%' AND h.motivo NOT LIKE 'No se pudo devolver%';
