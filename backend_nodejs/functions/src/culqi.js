/**
 * Pasarela de pagos Culqi (RF10, RF13) en MODO PRUEBA.
 * - La app convierte la tarjeta en un token con la llave pública (pk_test): los datos
 *   de la tarjeta nunca pasan por este servidor.
 * - Aquí se crea el cargo con la llave secreta (sk_test), que solo vive en el backend.
 * Sin CULQI_SECRET_KEY el cobro se simula (siempre aprobado), para poder probar sin cuenta.
 */
const crypto = require("node:crypto");
const logger = require("firebase-functions/logger");

const URL_API = "https://api.culqi.com/v2";
const TIEMPO_MAXIMO_MS = 15000;

function llaveSecreta() {
  return process.env.CULQI_SECRET_KEY || "";
}

/** true si hay llave de Culqi configurada (si no, los cobros son simulados). */
function culqiConfigurado() {
  return llaveSecreta().length > 0;
}

/**
 * Crea un cargo. Nunca lanza por un rechazo de la tarjeta: devuelve
 * { aprobado, idTransaccion, pasarela, mensaje }. Solo lanza si Culqi no responde.
 */
async function crearCargo({ monto, email, token, descripcion, idPedido }) {
  if (!culqiConfigurado()) {
    return {
      aprobado: true,
      idTransaccion: `SIM-${crypto.randomUUID()}`,
      pasarela: "Simulación (prototipo)",
      mensaje: null,
    };
  }

  const respuesta = await fetch(`${URL_API}/charges`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${llaveSecreta()}` },
    body: JSON.stringify({
      amount: Math.round(monto * 100), // Culqi trabaja en céntimos
      currency_code: "PEN",
      email,
      source_id: token,
      description: descripcion.slice(0, 80),
      metadata: { id_pedido: String(idPedido) },
    }),
    signal: AbortSignal.timeout(TIEMPO_MAXIMO_MS),
  });
  const cuerpo = await respuesta.json().catch(() => ({}));

  if (respuesta.ok && cuerpo.object === "charge") {
    return { aprobado: true, idTransaccion: cuerpo.id, pasarela: "Culqi (prueba)", mensaje: null };
  }
  // merchant_message es técnico: queda en el registro; al cliente solo se le muestra user_message.
  logger.warn("Culqi rechazó el cargo", {
    codigo: cuerpo.code, motivo: cuerpo.decline_code, tipo: cuerpo.type, comercio: cuerpo.merchant_message,
  });
  return {
    aprobado: false,
    idTransaccion: cuerpo.charge_id || `RECHAZO-${crypto.randomUUID()}`,
    pasarela: "Culqi (prueba)",
    mensaje: cuerpo.user_message || "No pudimos procesar tu tarjeta. Revisa los datos o usa otra tarjeta.",
  };
}

/** Devuelve el dinero de un cargo (pedido cancelado después de cobrar). */
async function devolverCargo(idCargo, monto) {
  if (!culqiConfigurado() || !String(idCargo).startsWith("chr_")) return { devuelto: true, simulado: true };
  let respuesta;
  try {
    respuesta = await fetch(`${URL_API}/refunds`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${llaveSecreta()}` },
      body: JSON.stringify({ amount: Math.round(monto * 100), charge_id: idCargo, reason: "solicitud_comprador" }),
      signal: AbortSignal.timeout(TIEMPO_MAXIMO_MS),
    });
  } catch (error) {
    logger.error("Culqi no respondió a la devolución", error.message);
    return { devuelto: false };
  }
  const cuerpo = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok) {
    logger.error("Culqi no pudo devolver el cargo", { idCargo, codigo: cuerpo.code });
    return { devuelto: false };
  }
  return { devuelto: true, idDevolucion: cuerpo.id };
}

module.exports = { culqiConfigurado, crearCargo, devolverCargo };
