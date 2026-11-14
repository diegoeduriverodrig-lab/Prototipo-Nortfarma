# Backend: API de Boticas Felicidad (Cloud Functions + MySQL)

## Requisitos
- Node 24 portátil en `C:\Users\diego\node24` (Cloud Functions no admite Node 26).
- MySQL iniciado: `C:\Users\diego\mysql-portable\iniciar_mysql.bat`.

## Iniciar la API local
1. Iniciar MySQL.
2. Doble clic en `iniciar_emulador.bat`. Esperar el mensaje `All emulators ready`.
3. Probar en el navegador: http://127.0.0.1:5001/nortfarma-a7928/us-central1/salud
   Debe responder `{"estado":"ok","baseDeDatos":"conectada",...}`.
4. Panel del emulador (logs de cada llamada): http://127.0.0.1:4000

Desde el emulador de Android, la PC se alcanza en `10.0.2.2` (no `127.0.0.1`).

## Estructura
```
functions/
├── index.js          ← registra todas las funciones
├── .env.local        ← credenciales de MySQL, URL de Nortfarma y llaves (solo local, no se sube)
└── src/
    ├── db.js           ← pool de conexiones a nortfarma_db
    ├── sesion.js       ← roles y reglas de acceso (exigirSesion, exigirRol)
    ├── salud.js        ← GET /salud: comprueba API + MySQL
    ├── perfil.js       ← Sprint 1: obtenerPerfil, registrarPerfil
    ├── catalogo.js     ← Sprint 2: obtenerCategorias, consultarCatalogo (con filtro de ofertas),
    │                     obtenerProducto
    ├── presentaciones.js ← caja / blíster / unidad de cada producto (precio y stock por presentación)
    ├── carrito.js      ← valida el carrito contra Nortfarma (precio, descuento, stock por botica)
    ├── sincronizacion.js ← copia diaria de productos y boticas (sincronizacionDiaria, sincronizarCatalogo)
    ├── entrega.js      ← Sprint 3: obtenerBoticas, obtenerUbigeos, listarDirecciones,
    │                     guardarDireccion, cotizarEnvio
    ├── recetas.js      ← Sprint 3: subirReceta, verReceta (RF14; la receta solo se adjunta, no se valida)
    ├── pedidos.js      ← Sprint 3: validarCarrito, registrarPedido (transacción SQL + venta en Nortfarma)
    ├── seguimiento.js  ← RF03: misPedidos, obtenerPedido (cada rol ve solo lo suyo)
    ├── encargado.js    ← Sprint 4: bandejaPedidos, actualizarEstadoPedido,
    │                     listarRepartidores, asignarRepartidor
    ├── repartidor.js   ← Sprint 4: misEntregas, actualizarEntrega
    ├── admin.js        ← Sprint 4: resumenAdmin, todosLosPedidos, listarPersonal, crearPersonal,
    │                     actualizarPersonal, quitarAccesoPersonal, listarProductosAdmin, actualizarProducto
    ├── estados_pedido.js ← utilidades comunes para cambiar estados (transacción, historial, anular venta)
    ├── core_cliente.js ← cliente HTTP del Sistema de Nortfarma (lo único que habla con Nortfarma)
    └── core_mock.js    ← Mock API del Sistema de Nortfarma (lee la base nortfarma_core)
recetas_local/        ← fotos de recetas (solo prototipo; en producción, Firebase Storage)
```

## Reglas del prototipo
- Zona atendida: Piura, Castilla y Veintiséis de Octubre (tabla Ubigeo).
- Delivery: todos los deliverys salen de UNA botica, la F24 (Galería Country, junto al BCP)
  (`Botica.hace_delivery`). Debe tener stock de todo el carrito.
  Envío S/ 5.00 hasta 2 km + S/ 1.50 por km extra; máximo 15 km.
- Recojo: en cualquiera de las 52 boticas de la zona, incluida la de delivery, si tiene stock de todo
  el carrito (la app deshabilita las demás).
- Comprobante: lo asigna Nortfarma al registrar la venta, como V + 4 dígitos (V0001, V0002...).
- Dirección: la ubicación sale de Google Maps y su distrito debe ser uno de la tabla Ubigeo
  (si no, no hay delivery). Sin Maps, se usa el centro del distrito elegido.
- Presentaciones: el cliente elige caja (empaque), blíster o unidad (fracción), según lo que
  Nortfarma tenga habilitado para ese producto. Cada una tiene su precio y su stock.
- Descuentos: vienen de la tabla de descuentos de Nortfarma (vigentes entre fecha de inicio y fin).
  El catálogo muestra precio regular tachado y precio con descuento; Inicio muestra las ofertas.
- Detalle_Pedido guarda el precio UNITARIO pagado (con descuento), el % de descuento, el id del
  precio en Nortfarma y el nombre: quedan como histórico aunque luego cambien.
- Pago con tarjeta: Culqi en modo prueba (`src/culqi.js`). La app crea el token con la llave
  pública; el backend crea el cargo con `CULQI_SECRET_KEY`. Si la llave está vacía, el cobro se simula.
  El pedido se guarda primero; si el cobro se rechaza queda un Pago "Fallido" y el cliente reintenta
  con `pagarPedido`. El encargado no puede empaquetar un pedido en línea sin pago aprobado.
  Si un pedido cobrado se cancela, se pide la devolución a Culqi. Yape/Plin sigue simulado.
  Ver `../CONFIGURAR_CLAVES.md`.
- Contraentrega (POS, efectivo): el pago queda "Pendiente" y pasa a "Aprobado" al entregar.
- Estados: Procesando → Empaquetado → En camino (delivery, con repartidor) o Listo para recoger
  (recojo) → Entregado. Desde cualquiera antes de Entregado → Fallido (con motivo; el stock vuelve al Core).
- Receta médica: el cliente adjunta la foto y el pedido sigue normal (nadie la valida en la app).
  Recojo en tienda: se confirma con el DNI del cliente.
- Las fechas se devuelven como texto ISO 8601 (Cloud Functions no serializa objetos Date).
- Personal: el Administrador crea las cuentas desde la app. En local se usa la API REST de
  Firebase Auth con `APP_API_KEY` (las variables `FIREBASE_*` están reservadas); en producción,
  el Admin SDK. "Quitar acceso" deja la cuenta como Cliente (borrarla requiere el Admin SDK).
- El primer Administrador se crea a mano: registrarlo en la app y usar `base_datos/asignar_rol_personal.sql`.

## Sistema de Nortfarma (simulado)
La función `coreApi` simula la API de la empresa sobre la base `nortfarma_core`
(ver `../base_datos/LEEME.md`). Para usar la API real, cambiar `CORE_API_URL`.
- `GET  /coreApi/productos` y `GET /coreApi/boticas`: datos para la copia diaria.
- `POST /coreApi/stock` con `{"referencias": [...], "boticas": [...]}`: precio, descuento y stock.
- `GET  /coreApi/descuentos`: productos en oferta hoy.
- `POST /coreApi/ventas`: registra la venta (descuenta stock y devuelve el comprobante V0001...).
- `POST /coreApi/ventas/<id>/pago` y `POST /coreApi/ventas/<id>/anular`.

## Instalar paquetes nuevos
Usar el npm de Node 24:
```
set PATH=C:\Users\diego\node24\node-v24.21.0-win-x64;%PATH%
cd functions
npm install <paquete>
```

## Servidor en AWS (APK final)
El APK final usa el backend publicado en **AWS Lightsail** (Ubuntu 24.04, 2 GB, Ohio):
`https://18-216-123-40.sslip.io/api/<función>`. La depuración (`flutter run`) sigue usando el emulador local.

- `functions/servidor.js` ejecuta las mismas funciones de `index.js` con Express
  (callables con el protocolo de Cloud Functions; la sesión se valida con Firebase Auth).
- En el servidor: `/opt/nortfarma/backend_nodejs` (servicio `nortfarma`), MySQL 8.0 local
  (`lower_case_table_names=1`, igual que en Windows) y Caddy para HTTPS.
- Las contraseñas de MySQL viven solo en `/opt/nortfarma/backend_nodejs/functions/.env` del servidor.
- La sincronización diaria corre a las 3:00 a. m. (hora de Lima) dentro de `servidor.js`.
- Acceso: `ssh -i %USERPROFILE%\.ssh\nortfarma-lightsail.pem ubuntu@18.216.123.40`
  - Ver registros: `sudo journalctl -u nortfarma -f`
  - Reiniciar: `sudo systemctl restart nortfarma`
- Generar el APK: `flutter build apk --release --dart-define-from-file=config/claves.json`
- Copias de seguridad en el servidor: `/var/backups/nortfarma/` (antes de cada cambio grande).

## Mejoras del 10/11/2026
- **Categorías administrables** (`listarCategoriasAdmin`, `guardarCategoria`, `eliminarCategoria`):
  crear, editar, ocultar (`Categoria_App.activa`) y eliminar solo si no tienen productos.
- **Fotos subidas desde el celular** (`subirImagenProducto`) y **evidencia de entrega** (`subirEvidencia`):
  se guardan en `imagenes_local/productos` y `imagenes_local/evidencias` (o en `IMAGENES_DIR`)
  y se ven con `verImagen?ruta=...`. Igual que las recetas; en producción se usaría Amazon S3.
- **Nombre en la app** (`Producto_App.nombre_app`): lo que ve el cliente; la sincronización no lo toca.
- **Entregas** (`Entrega`, `Incidencia_Entrega`): horas de asignación, salida y entrega, foto obligatoria al
  entregar, ubicación GPS y `reportarIncidencia` para problemas que no terminan la entrega.
