const { onCall, HttpsError } = require("firebase-functions/https");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const { SELECT_RESUMEN, resumenAJson } = require("./seguimiento");
const {
  ESTADO,
  cambiarEstado,
  registrarCobroContraentrega,
  pasarAFallido,
  registrarSalida,
  registrarEntregaRealizada,
  registrarIncidencia,
  enTransaccion,
  textoLimpio,
  exigirId,
} = require("./estados_pedido");
const { esRutaImagen } = require("./imagenes");

/** Motivos de entrega fallida que el repartidor puede elegir (Figura 11). */
const MOTIVOS_FALLO = [
  "Cliente ausente",
  "Dirección incorrecta o no encontrada",
  "Cliente rechazó el pedido",
  "Cliente no pudo pagar",
  "Otro",
];

/** Incidencias que no terminan la entrega: el repartidor las reporta y sigue en camino. */
const TIPOS_INCIDENCIA = [
  "Retraso por tráfico",
  "Cliente no responde",
  "Dirección difícil de ubicar",
  "Problema con el vehículo",
  "Otro",
];

/**
 * misEntregas (RF06, RF22): pedidos asignados al repartidor.
 * activas: empaquetados o en camino; recientes: las últimas finalizadas.
 */
exports.misEntregas = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.REPARTIDOR);
  const [activas] = await obtenerPool().query(
    `${SELECT_RESUMEN}
      WHERE p.id_repartidor = ? AND p.id_estado_pedido IN (?, ?)
      ORDER BY (p.id_estado_pedido = ?) DESC, p.fecha_pedido`,
    [perfil.idUsuario, ESTADO.EMPAQUETADO, ESTADO.EN_CAMINO, ESTADO.EN_CAMINO],
  );
  const [recientes] = await obtenerPool().query(
    `${SELECT_RESUMEN}
      WHERE p.id_repartidor = ? AND p.id_estado_pedido IN (?, ?)
      ORDER BY p.fecha_pedido DESC LIMIT 20`,
    [perfil.idUsuario, ESTADO.ENTREGADO, ESTADO.FALLIDO],
  );
  return {
    activas: activas.map(resumenAJson),
    recientes: recientes.map(resumenAJson),
    motivosFallo: MOTIVOS_FALLO,
    tiposIncidencia: TIPOS_INCIDENCIA,
  };
});

/**
 * actualizarEntrega (RF07): el repartidor avanza su entrega.
 * Empaquetado → En camino → Entregado, o En camino → Fallido (con motivo).
 * Al entregar es obligatoria la foto de evidencia (subirEvidencia); la ubicación GPS y la
 * observación son opcionales. Se registra el cobro contraentrega.
 * Si falla, queda la incidencia y el stock vuelve al inventario.
 */
exports.actualizarEntrega = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.REPARTIDOR);
  const idPedido = exigirId(request.data?.idPedido, "Entrega no válida.");
  const nuevo = Number(request.data?.idEstado);
  const motivo = textoLimpio(request.data?.motivo, 60);
  const detalle = textoLimpio(request.data?.detalle, 200);
  const evidencia = leerEvidencia(request.data);

  const permitidas = {
    [ESTADO.EMPAQUETADO]: [ESTADO.EN_CAMINO],
    [ESTADO.EN_CAMINO]: [ESTADO.ENTREGADO, ESTADO.FALLIDO],
  };

  return enTransaccion(async (conexion) => {
    const [filas] = await conexion.query(
      "SELECT id_pedido, id_repartidor, id_estado_pedido FROM Pedido WHERE id_pedido = ? FOR UPDATE",
      [idPedido],
    );
    const pedido = filas[0];
    if (!pedido || pedido.id_repartidor !== perfil.idUsuario) {
      throw new HttpsError("not-found", "La entrega no existe o no está asignada a ti.");
    }
    if (!permitidas[pedido.id_estado_pedido]?.includes(nuevo)) {
      throw new HttpsError("failed-precondition", "Ese cambio no está permitido para esta entrega.");
    }

    if (nuevo === ESTADO.FALLIDO) {
      if (!MOTIVOS_FALLO.includes(motivo)) throw new HttpsError("invalid-argument", "Elige el motivo.");
      if (motivo === "Otro" && detalle.length < 3) {
        throw new HttpsError("invalid-argument", "Describe qué pasó.");
      }
      await registrarIncidencia(conexion, pedido.id_pedido, motivo, detalle, true);
      await pasarAFallido(conexion, pedido, perfil.idUsuario, detalle ? `${motivo}: ${detalle}` : motivo);
      return { estado: nuevo };
    }
    if (nuevo === ESTADO.ENTREGADO && !evidencia.ruta) {
      throw new HttpsError("invalid-argument", "Toma la foto de la entrega antes de confirmarla.");
    }

    await cambiarEstado(conexion, pedido.id_pedido, nuevo, perfil.idUsuario);
    if (nuevo === ESTADO.EN_CAMINO) await registrarSalida(conexion, pedido.id_pedido);
    if (nuevo === ESTADO.ENTREGADO) {
      await registrarEntregaRealizada(conexion, pedido.id_pedido, evidencia);
      await registrarCobroContraentrega(conexion, pedido.id_pedido);
    }
    return { estado: nuevo };
  });
});

/**
 * reportarIncidencia: problema durante la entrega que no la termina (retraso, cliente
 * que no responde...). Queda registrado y la entrega sigue en curso.
 */
exports.reportarIncidencia = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.REPARTIDOR);
  const idPedido = exigirId(request.data?.idPedido, "Entrega no válida.");
  const tipo = textoLimpio(request.data?.tipo, 60);
  const detalle = textoLimpio(request.data?.detalle, 200);
  if (!TIPOS_INCIDENCIA.includes(tipo)) throw new HttpsError("invalid-argument", "Elige el tipo de incidencia.");
  if (tipo === "Otro" && detalle.length < 3) throw new HttpsError("invalid-argument", "Describe qué pasó.");

  return enTransaccion(async (conexion) => {
    const [filas] = await conexion.query(
      "SELECT id_repartidor, id_estado_pedido FROM Pedido WHERE id_pedido = ? FOR UPDATE",
      [idPedido],
    );
    const pedido = filas[0];
    if (!pedido || pedido.id_repartidor !== perfil.idUsuario) {
      throw new HttpsError("not-found", "La entrega no existe o no está asignada a ti.");
    }
    if (![ESTADO.EMPAQUETADO, ESTADO.EN_CAMINO].includes(pedido.id_estado_pedido)) {
      throw new HttpsError("failed-precondition", "Solo se reportan incidencias de entregas en curso.");
    }
    await registrarIncidencia(conexion, idPedido, tipo, detalle, false);
    return { ok: true };
  });
});

/** Foto (obligatoria al entregar), ubicación GPS y observación que envía la app. */
function leerEvidencia(data) {
  const ruta = esRutaImagen(data?.evidenciaRuta, "evidencias") ? data.evidenciaRuta : null;
  const latitud = Number(data?.latitud);
  const longitud = Number(data?.longitud);
  const conUbicacion = data?.latitud != null && data?.longitud != null &&
    Number.isFinite(latitud) && Number.isFinite(longitud) &&
    Math.abs(latitud) <= 90 && Math.abs(longitud) <= 180;
  return {
    ruta,
    latitud: conUbicacion ? latitud : null,
    longitud: conUbicacion ? longitud : null,
    observacion: textoLimpio(data?.observacion, 255) || null,
  };
}
