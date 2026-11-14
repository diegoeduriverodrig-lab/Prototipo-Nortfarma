# Bases de datos

Hay **dos** bases de datos en el mismo MySQL:

| Base | Qué es | Quién la usa |
|---|---|---|
| `nortfarma_db` | Base de datos **de la app** (16 tablas) | Backend de la app (usuario `nortfarma_app`) |
| `nortfarma_core` | **Sistema de Nortfarma simulado** (versión reducida de la base de la empresa) | Solo la API simulada `coreApi` (usuario `nortfarma_core_app`) |

La app nunca lee `nortfarma_core` directamente: le pide los datos a la API de Nortfarma,
igual que haría con el sistema real.

## Qué datos viajan entre las dos (colores del documento)
- **NARANJA (copia diaria):** productos (referencia, nombre, receta, especificaciones, presentaciones)
  y boticas (código, nombre, dirección, zona, horarios, ubicación) se copian a `nortfarma_db`.
  Función `sincronizacionDiaria` (3:00 a. m.) o botón "Sincronizar con Nortfarma" del Administrador.
- **VERDE (tiempo real):** precio, descuento y stock de cada presentación (caja, blíster, unidad),
  por botica. No se guardan en la app.
- **ROSADO (de la app a Nortfarma):** al registrar un pedido se crea la **venta** en Nortfarma
  (descuenta el stock de la botica y asigna el comprobante, ej. `V0001`); al aprobarse
  el pago se informa el id de la transacción; si el pedido se cancela, la venta se anula y el stock vuelve.

## Archivos
- `nortfarma_db.sql`: crea la base de la app y sus 16 tablas.
- `datos_iniciales.sql`: roles, estados, tipos de pago, ubigeos y categorías.
- `precarga_app.sql`: carga inicial de productos (con su categoría) y boticas desde Nortfarma.
- `nortfarma_core/`: el sistema de Nortfarma simulado.
  - `datos_origen/`: los Excel que envió Nortfarma (1400 productos y 113 boticas).
  - `generar_core.py`: arma `nortfarma_core.sql` y `../precarga_app.sql` a partir de los Excel.
  - `nortfarma_core.sql`: estructura y datos de `nortfarma_core`.
- `migracion_2026-10-15.sql`, `migracion_2026-10-16.sql` y `migracion_2026-10-16b.sql`: cómo se pasó
  de cada versión a la siguiente (la "b" carga las 52 boticas sin borrar pedidos).
- `migracion_2026-11-10.sql`: categorías que se pueden ocultar, nombre en la app y tablas `Entrega` e
  `Incidencia_Entrega` (arma las entregas anteriores desde el historial). Ya está incluida en `nortfarma_db.sql`.
- `carga_nombres_app.sql`: nombre en la app de 1149 productos, generado desde el nombre de Nortfarma con
  `generar_nombres_app.py` (desarrolla abreviaturas: TABX500MGX8 -> 500 mg x 8 tabletas). Los nombres con
  abreviaturas dudosas se dejan para que el Administrador los complete desde la app.
- `imagenes_productos.sql`: foto principal de 525 productos, buscada por código de barras exacto en
  tiendas en línea (Farmacia Universal y Plaza Vea) y Open Food Facts. Guarda el enlace directo, así que
  la foto depende de esas tiendas. Son referenciales, solo para el prototipo.
- `respaldo_*.sql`: copias de seguridad.

## Datos reales y datos de prueba
Del Excel de Nortfarma son reales: referencia, nombre, código de barras, categoría, laboratorio,
unidades del empaque, precio de venta (P.V.U.) y horarios de las boticas.
El Excel trae vacías algunas columnas. Se completaron así:
- **Tipo de receta:** según DIGEMID (D.S. 023-2001-SA, listas de sustancias controladas, y el
  listado de venta sin receta). Criterio y fuentes en `nortfarma_core/receta_digemid.py`.
  Productos con receta **retenida o especial** no se muestran en la app.
- **Boticas de la app (52):** las de la zona objetivo (Piura, Castilla y Veintiséis de Octubre),
  con código, nombre y dirección del Excel de Nortfarma (`datos_origen/boticas_zona_piura.xlsx`).
  Las coordenadas salen de OpenStreetMap; cada una indica su precisión en `generar_core.py`
  (exacta, calle, zona o estimada). La de delivery es la **F24** (Galería Country, junto al BCP).
- **Datos de prueba:** blíster, fracción, stock, vencimiento, refrigerado y descuentos.

## Recrear todo desde cero (borra los datos)
En MySQL Workbench (o con `mysql -u root -p`), ejecutar en este orden:
1. `nortfarma_db.sql`
2. `datos_iniciales.sql`
3. `precarga_app.sql`
4. `nortfarma_core/nortfarma_core.sql`

Los usuarios de la app se crean desde la app (necesitan cuenta de Firebase).

## Servidor MySQL (portátil, sin instalación)
- Carpeta: `C:\Users\diego\mysql-portable`
- Se enciende y apaga con los accesos directos del Escritorio "Iniciar / Apagar Boticas Felicidad".
- Solo acepta conexiones desde esta PC (127.0.0.1:3306).

## Usuarios (solo para desarrollo local)
| Usuario | Contraseña | Uso |
|---|---|---|
| `root` | `Nortfarma2026!` | Administrar desde Workbench |
| `nortfarma_app` | `AppFelicidad2026!` | Backend de la app. Solo accede a `nortfarma_db` |
| `nortfarma_core_app` | `CoreNortfarma2026!` | API simulada de Nortfarma. Solo accede a `nortfarma_core` |

## Conectar desde MySQL Workbench
1. En la pantalla de inicio, clic en el **+** junto a "MySQL Connections".
2. Connection Name: `Boticas Felicidad` · Hostname: `127.0.0.1` · Port: `3306` · Username: `root`.
3. Clic en **Store in Vault...**, escribir la contraseña y **OK**.
4. **Test Connection** y luego **OK**. Doble clic en la conexión para abrirla.
5. A la izquierda, en **Schemas**, aparecen `nortfarma_db` (app) y `nortfarma_core` (Nortfarma).
