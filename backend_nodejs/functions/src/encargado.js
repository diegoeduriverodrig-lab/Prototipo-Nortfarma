const { onCall, HttpsError } = require("firebase-functions/https");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const { SELECT_RESUMEN, resumenAJson } = require("./seguimiento");
const {
  ESTADO,
  PAGO,
  registrarHistorial,
  cambiarEstado,
  registrarCobroContraentrega,
  pasarAFallido,
  registrarAsignacion,
  registrarSalida,
  registrarEntregaRealizada,
  enTransaccion,
} = require("./estados_pedido");

/** Desde cada estado, a cuáles se puede pasar (flujo del Encargado, Figura 10). */
const TRANSICIONES = {
  [ESTADO.PROCESANDO]: [ESTADO.EMPAQUETADO, ESTADO.FALLIDO],
  [ESTADO.EMPAQUETADO]: [ESTADO.EN_CAMINO, ESTADO.LISTO_RECOGER, ESTADO.FALLIDO],
  [ESTADO.EN_CAMINO]: [ESTADO.ENTREGADO, ESTADO.FALLIDO],
  [ESTADO.LISTO_RECOGER]: [ESTADO.ENTREGADO, ESTADO.FALLIDO],
  [ESTADO.ENTREGADO]: [],
  [ESTADO.FALLIDO]: [],
};

/** El encargado solo trabaja con su botica. */
async function exigirEncargado(request) {
  const perfil = await exigirRol(request, ROLES.ENCARGADO);
  if (!perfil.idBotica) {
    throw new HttpsError("failed-precondition", "Tu cuenta no tiene una botica asignada. Contacta al administrador.");
  }
  return perfil;
}

/** bandejaPedidos (RF07): pedidos de la botica, con filtro por estado y totales por estado. */
exports.bandejaPedidos = onCall(async (request) => {
  const perfil = await exigirEncargado(request);
  const idEstado = Number.isInteger(request.data?.idEstado) ? request.data.idEstado : null;

  const [filas] = await obtenerPool().query(
    `${SELECT_RESUMEN}
      WHERE p.id_botica = ? ${idEstado ? "AND p.id_estado_pedido = ?" : ""}
      ORDER BY (p.id_estado_pedido = ${ESTADO.PROCESANDO}) DESC, p.fecha_pedido DESC, p.id_pedido DESC
      LIMIT 100`,
    idEstado ? [perfil.idBotica, idEstado] : [perfil.idBotica],
  );
  const [conteos] = await obtenerPool().query(
    `SELECT ep.id_estado_pedido, ep.nombre, COUNT(p.id_pedido) AS cantidad
       FROM Estado_Pedido ep
       LEFT JOIN Pedido p ON p.id_estado_pedido = ep.id_estado_pedido AND p.id_botica = ?
      GROUP BY ep.id_estado_pedido ORDER BY ep.id_estado_pedido`,
    [perfil.idBotica],
  );
  const [botica] = await obtenerPool().query("SELECT nombre FROM Botica WHERE id_botica = ?", [perfil.idBotica]);

  return {
    botica: botica[0]?.nombre ?? "",
    pedidos: filas.map(resumenAJson),
    conteos: conteos.map((c) => ({ id: c.id_estado_pedido, nombre: c.nombre, cantidad: Number(c.cantidad) })),
  };
});

/**
 * actualizarEstadoPedido (RF05): avanza el pedido según el flujo.
 * - Empaquetado: si se paga en línea, el pago debe estar aprobado.
 *   (La receta médica solo se adjunta como foto: no se valida.)
 * - En camino: solo delivery y con repartidor asignado.
 * - Listo para recoger: solo recojo en botica.
 * - Entregado (recojo): se confirma con el DNI del cliente y se registra el pago pendiente.
 * - Fallido: requiere motivo; el stock vuelve al inventario.
 */
exports.actualizarEstadoPedido = onCall(async (request) => {
  const perfil = await exigirEncargado(request);
  const { idPedido } = request.data || {};
  const nuevo = Number(request.data?.idEstado);
  const motivo = typeof request.data?.motivo === "string" ? request.data.motivo.trim().slice(0, 200) : "";
  const dniCliente = typeof request.data?.dniCliente === "string" ? request.data.dniCliente.trim() : "";

  return enTransaccion(async (conexion) => {
    const pedido = await bloquearPedido(conexion, idPedido, perfil.idBotica);
    const actual = pedido.id_estado_pedido;
    if (!TRANSICIONES[actual]?.includes(nuevo)) {
      throw new HttpsError("failed-precondition", "Ese cambio de estado no está permitido para este pedido.");
    }
    const esDelivery = pedido.tipo_entrega === "Delivery";

    if (nuevo === ESTADO.EMPAQUETADO) {
      // Pago en línea (tarjeta, Yape/Plin): no se prepara hasta que el cobro esté aprobado.
      if ([1, 2].includes(pedido.id_tipo_pago)) {
        const [pagos] = await conexion.query(
          "SELECT COUNT(*) AS n FROM Pago WHERE id_pedido = ? AND id_estado_pago = ?",
          [pedido.id_pedido, PAGO.APROBADO],
        );
        if (Number(pagos[0].n) === 0) {
          throw new HttpsError("failed-precondition", "El pago en línea aún no está aprobado.");
        }
      }
    }
    if (nuevo === ESTADO.EN_CAMINO && (!esDelivery || !pedido.id_repartidor)) {
      throw new HttpsError("failed-precondition", esDelivery
        ? "Asigna un repartidor antes de enviar el pedido."
        : "Los pedidos de recojo no se envían.");
    }
    if (nuevo === ESTADO.LISTO_RECOGER && esDelivery) {
      throw new HttpsError("failed-precondition", "Este pedido es delivery: asigna un repartidor.");
    }
    if (nuevo === ESTADO.ENTREGADO && !esDelivery) {
      const [clientes] = await conexion.query("SELECT dni FROM Usuario WHERE id_usuario = ?", [pedido.id_cliente]);
      if (dniCliente !== clientes[0]?.dni) {
        throw new HttpsError("failed-precondition", "El DNI no coincide con el del cliente del pedido.");
      }
    }
    if (nuevo === ESTADO.FALLIDO) {
      if (motivo.length < 3) throw new HttpsError("invalid-argument", "Escribe el motivo.");
      await pasarAFallido(conexion, pedido, perfil.idUsuario, motivo);
      return { estado: nuevo };
    }

    await cambiarEstado(conexion, pedido.id_pedido, nuevo, perfil.idUsuario, motivo || null);
    if (esDelivery && nuevo === ESTADO.EN_CAMINO) await registrarSalida(conexion, pedido.id_pedido);
    if (esDelivery && nuevo === ESTADO.ENTREGADO) {
      await registrarEntregaRealizada(conexion, pedido.id_pedido, { observacion: "Entrega confirmada por la botica" });
    }
    if (nuevo === ESTADO.ENTREGADO) await registrarCobroContraentrega(conexion, pedido.id_pedido);
    return { estado: nuevo };
  });
});

/** listarRepartidores (RF06): repartidores con la cantidad de entregas activas. */
exports.listarRepartidores = onCall(async (request) => {
  await exigirEncargado(request);
  const [filas] = await obtenerPool().query(
    `SELECT u.id_usuario, u.nombre, u.apellido, u.telefono,
            (SELECT COUNT(*) FROM Pedido p
              WHERE p.id_repartidor = u.id_usuario
                AND p.id_estado_pedido IN (${ESTADO.EMPAQUETADO}, ${ESTADO.EN_CAMINO})) AS activos
       FROM Usuario u WHERE u.id_rol = ? ORDER BY activos, u.nombre`,
    [ROLES.REPARTIDOR],
  );
  return {
    repartidores: filas.map((r) => ({
      id: r.id_usuario,
      nombre: `${r.nombre} ${r.apellido}`,
      telefono: r.telefono,
      entregasActivas: Number(r.activos),
    })),
  };
});

/** asignarRepartidor (RF06): solo pedidos delivery ya empaquetados. */
exports.asignarRepartidor = onCall(async (request) => {
  const perfil = await exigirEncargado(request);
  const { idPedido } = request.data || {};
  const idRepartidor = Number(request.data?.idRepartidor);

  return enTransaccion(async (conexion) => {
    const pedido = await bloquearPedido(conexion, idPedido, perfil.idBotica);
    if (pedido.tipo_entrega !== "Delivery") {
      throw new HttpsError("failed-precondition", "Solo los pedidos delivery llevan repartidor.");
    }
    if (pedido.id_estado_pedido !== ESTADO.EMPAQUETADO) {
      throw new HttpsError("failed-precondition", "Asigna el repartidor cuando el pedido esté empaquetado.");
    }
    const [repartidores] = await conexion.query(
      "SELECT nombre, apellido FROM Usuario WHERE id_usuario = ? AND id_rol = ?",
      [idRepartidor, ROLES.REPARTIDOR],
    );
    if (repartidores.length === 0) throw new HttpsError("invalid-argument", "Elige un repartidor.");

    await conexion.execute("UPDATE Pedido SET id_repartidor = ? WHERE id_pedido = ?", [idRepartidor, pedido.id_pedido]);
    await registrarAsignacion(conexion, pedido.id_pedido, idRepartidor);
    const nombre = `${repartidores[0].nombre} ${repartidores[0].apellido}`;
    await registrarHistorial(conexion, pedido.id_pedido, ESTADO.EMPAQUETADO, perfil.idUsuario,
      `Repartidor asignado: ${nombre}`);
    return { repartidor: nombre };
  });
});

// ---------------------------------------------------------------------

/** Bloquea el pedido (FOR UPDATE) y comprueba que sea de la botica del encargado. */
async function bloquearPedido(conexion, idPedido, idBotica) {
  const id = Number(idPedido);
  if (!Number.isInteger(id) || id <= 0) throw new HttpsError("invalid-argument", "Pedido no válido.");
  const [filas] = await conexion.query(
    `SELECT id_pedido, id_cliente, id_botica, id_repartidor, id_estado_pedido, tipo_entrega, id_tipo_pago
       FROM Pedido WHERE id_pedido = ? FOR UPDATE`,
    [id],
  );
  if (filas.length === 0 || filas[0].id_botica !== idBotica) {
    throw new HttpsError("not-found", "El pedido no existe.");
  }
  return filas[0];
}
