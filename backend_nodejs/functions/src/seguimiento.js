const { onCall, HttpsError } = require("firebase-functions/https");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const { textoHorario } = require("./entrega");
const { nombrePresentacion, redondear } = require("./presentaciones");

/** misPedidos (RF03): historial de pedidos del cliente, del más reciente al más antiguo. */
exports.misPedidos = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const [filas] = await obtenerPool().query(
    `${SELECT_RESUMEN} WHERE p.id_cliente = ? ORDER BY p.fecha_pedido DESC, p.id_pedido DESC LIMIT 100`,
    [perfil.idUsuario],
  );
  return { pedidos: filas.map(resumenAJson) };
});

/**
 * obtenerPedido: detalle completo con productos, entrega, pago, receta e historial.
 * Cada rol solo ve lo suyo: el cliente sus pedidos, el encargado los de su botica,
 * el repartidor los asignados y el administrador todos.
 */
exports.obtenerPedido = onCall(async (request) => {
  const perfil = await exigirRol(request);
  const idPedido = Number(request.data?.idPedido);
  if (!Number.isInteger(idPedido) || idPedido <= 0) {
    throw new HttpsError("invalid-argument", "Pedido no válido.");
  }
  const detalle = await cargarDetalle(idPedido);
  if (!detalle || !puedeVer(perfil, detalle)) {
    throw new HttpsError("not-found", "El pedido no existe.");
  }
  // El cliente no necesita sus propios datos personales en el detalle.
  if (perfil.rol.id === ROLES.CLIENTE) delete detalle.cliente;
  delete detalle._acceso;
  return { pedido: detalle };
});

const SELECT_RESUMEN = `
  SELECT p.id_pedido, p.fecha_pedido, p.id_estado_pedido, ep.nombre AS estado,
         p.tipo_entrega, p.monto_total,
         c.nombre AS cliente_nombre, c.apellido AS cliente_apellido,
         (SELECT COUNT(*) FROM Detalle_Pedido dp WHERE dp.id_pedido = p.id_pedido) AS productos,
         EXISTS (SELECT 1 FROM Receta r WHERE r.id_pedido = p.id_pedido) AS tiene_receta,
         (SELECT es.nombre FROM Pago pg JOIN Estado_Pago es ON es.id_estado_pago = pg.id_estado_pago
           WHERE pg.id_pedido = p.id_pedido ORDER BY pg.id_pago DESC LIMIT 1) AS estado_pago,
         d.direccion_exacta, ub.distrito, b.nombre AS botica, tp.nombre AS tipo_pago
    FROM Pedido p
    JOIN Estado_Pedido ep ON ep.id_estado_pedido = p.id_estado_pedido
    JOIN Usuario c ON c.id_usuario = p.id_cliente
    JOIN Tipo_Pago tp ON tp.id_tipo_pago = p.id_tipo_pago
    LEFT JOIN Botica b ON b.id_botica = p.id_botica
    LEFT JOIN Direccion_Cliente d ON d.id_direccion = p.id_direccion
    LEFT JOIN Ubigeo ub ON ub.id_ubigeo = d.id_ubigeo`;

function resumenAJson(f) {
  return {
    idPedido: f.id_pedido,
    numero: numeroPedido(f.id_pedido),
    fecha: aIso(f.fecha_pedido),
    estado: { id: f.id_estado_pedido, nombre: f.estado },
    estadoPago: f.estado_pago,
    tipoEntrega: f.tipo_entrega,
    total: f.monto_total,
    productos: Number(f.productos),
    tieneReceta: Boolean(f.tiene_receta),
    cliente: `${f.cliente_nombre} ${f.cliente_apellido}`,
    direccion: f.direccion_exacta ? `${f.direccion_exacta}, ${f.distrito}` : null,
    botica: f.botica,
    tipoPago: f.tipo_pago,
  };
}

/** Carga todo el pedido. Devuelve null si no existe. */
async function cargarDetalle(idPedido, conexion = obtenerPool()) {
  const [filas] = await conexion.query(
    `SELECT p.*, ep.nombre AS estado, tp.nombre AS tipo_pago,
            b.nombre AS botica_nombre, b.direccion AS botica_direccion,
            b.hora_apertura_semana, b.hora_cierre_semana, b.hora_apertura_domingo, b.hora_cierre_domingo,
            b.latitud AS botica_lat, b.longitud AS botica_lng,
            d.direccion_exacta, d.referencia, ub.distrito, d.latitud AS dir_lat, d.longitud AS dir_lng,
            c.nombre AS c_nombre, c.apellido AS c_apellido, c.dni AS c_dni, c.telefono AS c_telefono,
            rp.nombre AS r_nombre, rp.apellido AS r_apellido, rp.telefono AS r_telefono
       FROM Pedido p
       JOIN Estado_Pedido ep ON ep.id_estado_pedido = p.id_estado_pedido
       JOIN Tipo_Pago tp ON tp.id_tipo_pago = p.id_tipo_pago
       JOIN Usuario c ON c.id_usuario = p.id_cliente
       LEFT JOIN Botica b ON b.id_botica = p.id_botica
       LEFT JOIN Direccion_Cliente d ON d.id_direccion = p.id_direccion
       LEFT JOIN Ubigeo ub ON ub.id_ubigeo = d.id_ubigeo
       LEFT JOIN Usuario rp ON rp.id_usuario = p.id_repartidor
      WHERE p.id_pedido = ?`,
    [idPedido],
  );
  if (filas.length === 0) return null;
  const p = filas[0];

  const [items] = await conexion.query(
    `SELECT dp.id_producto, dp.presentacion, dp.cantidad, dp.precio_historico, dp.descuento_historico,
            dp.nombre_historico, pa.requiere_receta, pa.empaque, pa.unidades_blister
       FROM Detalle_Pedido dp JOIN Producto_App pa ON pa.id_producto = dp.id_producto
      WHERE dp.id_pedido = ? ORDER BY dp.id_detalle`,
    [idPedido],
  );
  const [pagos] = await conexion.query(
    `SELECT pg.id_estado_pago, es.nombre AS estado, pg.monto_procesado, pg.pasarela, pg.fecha_pago
       FROM Pago pg JOIN Estado_Pago es ON es.id_estado_pago = pg.id_estado_pago
      WHERE pg.id_pedido = ? ORDER BY pg.id_pago DESC LIMIT 1`,
    [idPedido],
  );
  const [recetas] = await conexion.query(
    "SELECT imagen_url, fecha_carga FROM Receta WHERE id_pedido = ? ORDER BY id_receta DESC LIMIT 1",
    [idPedido],
  );
  const [historial] = await conexion.query(
    `SELECT h.id_estado_pedido, ep.nombre AS estado, h.motivo, h.fecha_cambio,
            u.nombre AS u_nombre, u.id_rol
       FROM Historial_Estado_Pedido h
       JOIN Estado_Pedido ep ON ep.id_estado_pedido = h.id_estado_pedido
       LEFT JOIN Usuario u ON u.id_usuario = h.id_usuario
      WHERE h.id_pedido = ? ORDER BY h.fecha_cambio, h.id_historial`,
    [idPedido],
  );
  const [entregas] = await conexion.query(
    `SELECT id_entrega, fecha_asignacion, fecha_salida, fecha_entrega, evidencia_url,
            latitud_entrega, longitud_entrega, observacion
       FROM Entrega WHERE id_pedido = ?`,
    [idPedido],
  );
  const entrega = entregas[0];
  const [incidencias] = entrega
    ? await conexion.query(
      `SELECT tipo, detalle, termina_entrega, fecha FROM Incidencia_Entrega
        WHERE id_entrega = ? ORDER BY fecha, id_incidencia`,
      [entrega.id_entrega],
    )
    : [[]];

  const pago = pagos[0];
  const receta = recetas[0];
  return {
    _acceso: { idCliente: p.id_cliente, idBotica: p.id_botica, idRepartidor: p.id_repartidor },
    idPedido: p.id_pedido,
    numero: numeroPedido(p.id_pedido),
    fecha: aIso(p.fecha_pedido),
    estado: { id: p.id_estado_pedido, nombre: p.estado },
    tipoEntrega: p.tipo_entrega,
    botica: p.id_botica
      ? {
        id: p.id_botica, nombre: p.botica_nombre, direccion: p.botica_direccion, horario: textoHorario(p),
        latitud: p.botica_lat, longitud: p.botica_lng,
      }
      : null,
    direccion: p.id_direccion
      ? {
        direccionExacta: p.direccion_exacta, referencia: p.referencia, distrito: p.distrito,
        latitud: p.dir_lat, longitud: p.dir_lng,
      }
      : null,
    comprobante: {
      tipo: p.tipo_comprobante, numero: p.numero_comprobante, ruc: p.ruc_facturacion, razonSocial: p.razon_social,
    },
    tipoPago: p.tipo_pago,
    idTipoPago: p.id_tipo_pago,
    pago: pago
      ? { idEstado: pago.id_estado_pago, estado: pago.estado, monto: pago.monto_procesado, pasarela: pago.pasarela }
      : null,
    receta: receta ? { ruta: receta.imagen_url, fecha: aIso(receta.fecha_carga) } : null,
    items: items.map((i) => ({
      idProducto: i.id_producto,
      nombre: i.nombre_historico,
      presentacion: i.presentacion,
      nombrePresentacion: nombrePresentacion(i, i.presentacion),
      cantidad: i.cantidad,
      precioUnitario: i.precio_historico,
      descuento: i.descuento_historico,
      total: redondear(i.precio_historico * i.cantidad),
      requiereReceta: Boolean(i.requiere_receta),
    })),
    costoEnvio: p.costo_envio,
    codigoPromocion: p.codigo_promocion,
    total: p.monto_total,
    cliente: { nombre: `${p.c_nombre} ${p.c_apellido}`, dni: p.c_dni, telefono: p.c_telefono },
    repartidor: p.id_repartidor
      ? { id: p.id_repartidor, nombre: `${p.r_nombre} ${p.r_apellido}`, telefono: p.r_telefono }
      : null,
    historial: historial.map((h) => ({
      estado: { id: h.id_estado_pedido, nombre: h.estado },
      motivo: h.motivo,
      fecha: aIso(h.fecha_cambio),
      responsable: h.u_nombre ?? null,
    })),
    entrega: entrega
      ? {
        fechaAsignacion: aIso(entrega.fecha_asignacion),
        fechaSalida: aIso(entrega.fecha_salida),
        fechaEntrega: aIso(entrega.fecha_entrega),
        evidencia: entrega.evidencia_url,
        latitud: entrega.latitud_entrega == null ? null : Number(entrega.latitud_entrega),
        longitud: entrega.longitud_entrega == null ? null : Number(entrega.longitud_entrega),
        observacion: entrega.observacion,
        incidencias: incidencias.map((i) => ({
          tipo: i.tipo,
          detalle: i.detalle,
          terminaEntrega: Boolean(i.termina_entrega),
          fecha: aIso(i.fecha),
        })),
      }
      : null,
  };
}

function puedeVer(perfil, detalle) {
  const a = detalle._acceso;
  switch (perfil.rol.id) {
    case ROLES.ADMINISTRADOR: return true;
    case ROLES.CLIENTE: return a.idCliente === perfil.idUsuario;
    case ROLES.ENCARGADO: return perfil.idBotica != null && a.idBotica === perfil.idBotica;
    case ROLES.REPARTIDOR: return a.idRepartidor === perfil.idUsuario;
    default: return false;
  }
}

function numeroPedido(id) {
  return `#${String(id).padStart(5, "0")}`;
}

module.exports.SELECT_RESUMEN = SELECT_RESUMEN;
module.exports.resumenAJson = resumenAJson;
module.exports.cargarDetalle = cargarDetalle;

/**
 * Las respuestas de Cloud Functions convierten un Date en un objeto vacío ({}),
 * así que las fechas se envían como texto ISO 8601 (UTC).
 */
function aIso(fecha) {
  return fecha instanceof Date ? fecha.toISOString() : fecha;
}
