const { onCall, HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const core = require("./core_cliente");
const { buscarDireccionDelCliente, calcularEnvio, buscarBotica, boticaAJson } = require("./entrega");
const { esRutaReceta } = require("./recetas");
const { prepararLineas, faltantesEn } = require("./carrito");
const { redondear } = require("./presentaciones");
const culqi = require("./culqi");

// Ids de los catálogos (datos_iniciales.sql).
const ESTADO_PEDIDO = { PROCESANDO: 1 };
const ESTADO_PAGO = { PENDIENTE: 1, APROBADO: 2, FALLIDO: 3 };
const TIPO_PAGO = { TARJETA: 1, YAPE_PLIN: 2, POS: 3, EFECTIVO: 4 };
const PAGOS_EN_LINEA = [TIPO_PAGO.TARJETA, TIPO_PAGO.YAPE_PLIN];
// Cómo se informa el medio de pago al sistema de Nortfarma.
const MEDIO_PAGO = { 1: "TARJETA", 2: "YAPE/PLIN", 3: "POS", 4: "EFECTIVO" };

/**
 * validarCarrito: al confirmar el carrito, consulta precio, descuento y stock actuales
 * de cada presentación (diagrama de actividad: validación de stock antes del checkout).
 */
exports.validarCarrito = onCall(async (request) => {
  await exigirRol(request, ROLES.CLIENTE);
  const { lineas, sinStock } = await prepararLineas(request.data?.items);
  return {
    items: lineas.map(lineaAJson),
    sinStock,
    subtotal: subtotalDe(lineas),
    requiereReceta: lineas.some((l) => l.requiereReceta),
  };
});

/**
 * registrarPedido (RF01, RF04, RF12, RF14).
 * Precios, descuentos, stock y costo de envío se calculan aquí: la app no los decide.
 * El pedido lo atiende una botica con stock de todo el carrito. Todo se guarda en una
 * transacción y la venta se registra en el sistema de Nortfarma, que descuenta el stock
 * y asigna el comprobante. Si algo falla se revierte con ROLLBACK y se anula la venta.
 */
exports.registrarPedido = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const data = request.data || {};

  const { lineas, sinStock } = await prepararLineas(data.items);
  if (sinStock.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      "Algunos productos ya no tienen stock suficiente. Revisa tu carrito.",
      { sinStock },
    );
  }

  const comprobante = validarComprobante(data.comprobante);
  const idTipoPago = Number(data.idTipoPago);
  if (!Object.values(TIPO_PAGO).includes(idTipoPago)) {
    throw new HttpsError("invalid-argument", "Elige un método de pago.");
  }
  const codigoPromocion = typeof data.codigoPromocion === "string"
    ? data.codigoPromocion.trim().toUpperCase().slice(0, 30) || null
    : null;

  // Con Culqi configurado, el pago con tarjeta exige el token creado por la app.
  const tokenCulqi = typeof data.tokenCulqi === "string" ? data.tokenCulqi.trim() : "";
  if (idTipoPago === TIPO_PAGO.TARJETA && culqi.culqiConfigurado() && !/^tkn_/.test(tokenCulqi)) {
    throw new HttpsError("invalid-argument", "Ingresa los datos de tu tarjeta.");
  }

  // La receta solo se adjunta (foto); nadie la valida en la app.
  const requiereReceta = lineas.some((l) => l.requiereReceta);
  if (requiereReceta && !esRutaReceta(data.recetaRuta)) {
    throw new HttpsError("invalid-argument", "Adjunta la foto de tu receta médica.");
  }

  // Entrega: delivery (botica más cercana con stock + costo por distancia) o recojo en botica.
  const entrega = data.entrega || {};
  let tipoEntrega;
  let idDireccion = null;
  let botica;
  let costoEnvio = 0;
  if (entrega.tipo === "delivery") {
    const direccion = await buscarDireccionDelCliente(Number(entrega.idDireccion), perfil.idUsuario);
    const envio = await calcularEnvio(direccion, lineas);
    tipoEntrega = "Delivery";
    idDireccion = direccion.id_direccion;
    botica = envio.botica;
    costoEnvio = envio.costo;
  } else if (entrega.tipo === "recojo") {
    botica = await buscarBotica(Number(entrega.idBotica));
    if (!botica) throw new HttpsError("invalid-argument", "Elige la botica de recojo.");
    const faltan = faltantesEn(lineas, botica.id_botica_core);
    if (faltan.length > 0) {
      throw new HttpsError("failed-precondition",
        `${botica.nombre} no tiene stock de: ${faltan.map((l) => l.nombre).join(", ")}. Elige otra botica.`);
    }
    tipoEntrega = "Retiro en Botica";
  } else {
    throw new HttpsError("invalid-argument", "Elige delivery o recojo en botica.");
  }

  const subtotal = subtotalDe(lineas);
  const total = redondear(subtotal + costoEnvio);
  const enLinea = PAGOS_EN_LINEA.includes(idTipoPago);

  const conexion = await obtenerPool().getConnection();
  let idPedido;
  let venta = null;
  try {
    await conexion.beginTransaction();

    const [r] = await conexion.execute(
      `INSERT INTO Pedido (id_cliente, id_botica, id_direccion, id_estado_pedido, id_tipo_pago,
                           tipo_entrega, tipo_comprobante, ruc_facturacion, razon_social,
                           costo_envio, codigo_promocion, monto_total)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [perfil.idUsuario, botica.id_botica, idDireccion, ESTADO_PEDIDO.PROCESANDO, idTipoPago,
        tipoEntrega, comprobante.tipo, comprobante.ruc, comprobante.razonSocial,
        costoEnvio, codigoPromocion, total],
    );
    idPedido = r.insertId;

    for (const l of lineas) {
      // Precio unitario (con descuento) y nombre de este momento: quedan como histórico.
      await conexion.execute(
        `INSERT INTO Detalle_Pedido (id_pedido, id_producto, presentacion, cantidad, precio_historico,
                                     descuento_historico, id_precio_core, nombre_historico)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [idPedido, l.idProducto, l.presentacion, l.cantidad, l.precio, l.descuento, l.idPrecio,
          l.nombre.slice(0, 150)],
      );
    }

    if (requiereReceta) {
      await conexion.execute("INSERT INTO Receta (id_pedido, imagen_url) VALUES (?, ?)", [idPedido, data.recetaRuta]);
    }

    await conexion.execute(
      "INSERT INTO Historial_Estado_Pedido (id_pedido, id_estado_pedido, id_usuario) VALUES (?, ?, ?)",
      [idPedido, ESTADO_PEDIDO.PROCESANDO, perfil.idUsuario],
    );

    // RF12: la venta viaja al sistema de Nortfarma, que descuenta el stock de la botica
    // y asigna la serie-correlativo del comprobante. Si falla, se revierte todo.
    venta = await registrarVentaEnNortfarma({ botica, idPedido, comprobante, idTipoPago, enLinea, lineas });
    await conexion.execute(
      "UPDATE Pedido SET id_venta_core = ?, numero_comprobante = ? WHERE id_pedido = ?",
      [venta.id_venta, venta.numero_comprobante, idPedido],
    );

    // Contraentrega: el pago queda "Pendiente" hasta la entrega.
    if (!enLinea) {
      await registrarPago(conexion, idPedido, idTipoPago, ESTADO_PAGO.PENDIENTE, total, null, `CONTRAENTREGA-${idPedido}`);
    }

    await conexion.commit();
  } catch (error) {
    await conexion.rollback();
    if (venta) await anularVentaSinFallar(venta.id_venta);
    if (error instanceof HttpsError) throw error;
    logger.error("Error al registrar el pedido", error);
    throw new HttpsError("internal", "No se pudo registrar tu pedido. Inténtalo de nuevo.");
  } finally {
    conexion.release();
  }

  // Pago en línea: se cobra después de guardar el pedido. Si se rechaza, queda el intento
  // "Fallido" y el cliente puede reintentar con otra tarjeta (pagarPedido).
  let resultadoPago = { estadoPago: "Por pagar", mensajePago: null };
  if (enLinea) {
    resultadoPago = await cobrar({
      idPedido, idTipoPago, total, email: perfil.correo, token: tokenCulqi, idVenta: venta.id_venta,
    });
  }

  return {
    idPedido,
    numero: numeroPedido(idPedido),
    comprobante: venta.numero_comprobante,
    estadoPedido: "Procesando",
    ...resultadoPago,
    tipoEntrega,
    botica: boticaAJson(botica),
    subtotal,
    costoEnvio,
    total,
  };
});

/** Envía la venta a Nortfarma y traduce sus errores a mensajes para el cliente. */
async function registrarVentaEnNortfarma({ botica, idPedido, comprobante, idTipoPago, enLinea, lineas }) {
  let venta;
  try {
    venta = await core.registrarVenta({
      botica_id: botica.id_botica_core,
      referencia_origen: numeroPedido(idPedido),
      tipo_comprobante: comprobante.tipo.toUpperCase(),
      ruc: comprobante.ruc,
      razon_social: comprobante.razonSocial,
      medio_pago: MEDIO_PAGO[idTipoPago],
      tipo_pago: enLinea ? "EN LINEA" : "CONTRAENTREGA",
      items: lineas.map((l) => ({
        referencia: l.idProductoCore, tipo: l.presentacion, cantidad: l.cantidad, id_precio: l.idPrecio,
      })),
    });
  } catch (error) {
    if (error.cuerpo?.codigo === "SIN_STOCK") {
      throw new HttpsError("failed-precondition", "Otro cliente compró las últimas unidades. Revisa tu carrito.");
    }
    if (error.cuerpo?.codigo === "PRECIO_CAMBIO") {
      throw new HttpsError("failed-precondition", "El precio de un producto acaba de cambiar. Revisa tu carrito.");
    }
    logger.error("Nortfarma no registró la venta", error.message);
    throw new HttpsError("unavailable", "El sistema de Nortfarma no responde. Inténtalo en unos minutos.");
  }
  if (Math.abs(venta.precio_total - subtotalDe(lineas)) > 0.009) {
    logger.warn("El total de Nortfarma no coincide con el de la app", { idPedido, nortfarma: venta.precio_total });
  }
  return venta;
}

async function anularVentaSinFallar(idVenta) {
  try {
    await core.anularVenta(idVenta);
  } catch (error) {
    logger.error("No se pudo anular la venta en Nortfarma: revisar a mano", { idVenta, error: error.message });
  }
}

/** Boleta, o Factura con RUC (11 dígitos) y razón social. */
function validarComprobante(c) {
  if (c?.tipo === "boleta") return { tipo: "Boleta", ruc: null, razonSocial: null };
  if (c?.tipo === "factura") {
    const ruc = typeof c.ruc === "string" ? c.ruc.trim() : "";
    const razonSocial = typeof c.razonSocial === "string" ? c.razonSocial.trim() : "";
    if (!/^(10|15|17|20)\d{9}$/.test(ruc)) {
      throw new HttpsError("invalid-argument", "El RUC debe tener 11 dígitos y empezar con 10, 15, 17 o 20.");
    }
    if (razonSocial.length < 3 || razonSocial.length > 150) {
      throw new HttpsError("invalid-argument", "Escribe la razón social de la empresa.");
    }
    return { tipo: "Factura", ruc, razonSocial };
  }
  throw new HttpsError("invalid-argument", "Elige boleta o factura.");
}

/**
 * pagarPedido (RF13): reintenta el pago en línea de un pedido cuyo cobro fue rechazado.
 * Cada intento queda registrado en la tabla Pago.
 */
exports.pagarPedido = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const idPedido = Number(request.data?.idPedido);
  const tokenCulqi = typeof request.data?.tokenCulqi === "string" ? request.data.tokenCulqi.trim() : "";

  const [filas] = await obtenerPool().query(
    `SELECT p.id_pedido, p.id_cliente, p.id_estado_pedido, p.id_tipo_pago, p.monto_total, p.id_venta_core,
            (SELECT COUNT(*) FROM Pago pg WHERE pg.id_pedido = p.id_pedido AND pg.id_estado_pago = ?) AS aprobados
       FROM Pedido p WHERE p.id_pedido = ?`,
    [ESTADO_PAGO.APROBADO, Number.isInteger(idPedido) ? idPedido : 0],
  );
  const pedido = filas[0];
  if (!pedido || pedido.id_cliente !== perfil.idUsuario) throw new HttpsError("not-found", "El pedido no existe.");
  if (!PAGOS_EN_LINEA.includes(pedido.id_tipo_pago)) {
    throw new HttpsError("failed-precondition", "Este pedido se paga al recibirlo.");
  }
  if (Number(pedido.aprobados) > 0) throw new HttpsError("failed-precondition", "Este pedido ya está pagado.");
  if (pedido.id_estado_pedido !== ESTADO_PEDIDO.PROCESANDO) {
    throw new HttpsError("failed-precondition", "Este pedido ya no se puede pagar.");
  }
  if (pedido.id_tipo_pago === TIPO_PAGO.TARJETA && culqi.culqiConfigurado() && !/^tkn_/.test(tokenCulqi)) {
    throw new HttpsError("invalid-argument", "Ingresa los datos de tu tarjeta.");
  }

  return cobrar({
    idPedido,
    idTipoPago: pedido.id_tipo_pago,
    total: pedido.monto_total,
    email: perfil.correo,
    token: tokenCulqi,
    idVenta: pedido.id_venta_core,
  });
});

/**
 * Cobra en la pasarela y registra el intento en la tabla Pago. Si se aprueba, se
 * informa el pago a Nortfarma (la venta queda pagada, con el id de la transacción).
 * Tarjeta: Culqi (modo prueba). Yape/Plin: simulado (Culqi exige un código OTP de la app Yape).
 */
async function cobrar({ idPedido, idTipoPago, total, email, token, idVenta }) {
  let resultado;
  try {
    resultado = idTipoPago === TIPO_PAGO.TARJETA
      ? await culqi.crearCargo({ monto: total, email, token, descripcion: `Boticas Felicidad ${numeroPedido(idPedido)}`, idPedido })
      : { aprobado: true, idTransaccion: `SIM-YAPE-${idPedido}-${Date.now()}`, pasarela: "Simulación Yape/Plin" };
  } catch (error) {
    logger.error("La pasarela de pagos no respondió", error.message);
    resultado = { aprobado: false, idTransaccion: `SIN-RESPUESTA-${idPedido}-${Date.now()}`, pasarela: "Culqi (prueba)",
      mensaje: "La pasarela de pagos no respondió. Inténtalo de nuevo." };
  }

  await registrarPago(obtenerPool(), idPedido, idTipoPago,
    resultado.aprobado ? ESTADO_PAGO.APROBADO : ESTADO_PAGO.FALLIDO,
    total, resultado.pasarela, resultado.idTransaccion);
  if (resultado.aprobado && idVenta) {
    await informarPagoANortfarma(idVenta, resultado.pasarela, resultado.idTransaccion);
  }

  return {
    estadoPago: resultado.aprobado ? "Pagado" : "Fallido",
    mensajePago: resultado.aprobado ? null : resultado.mensaje,
  };
}

async function registrarPago(conexion, idPedido, idTipoPago, idEstado, monto, pasarela, token) {
  await conexion.execute(
    `INSERT INTO Pago (id_pedido, id_tipo_pago, id_estado_pago, monto_procesado, pasarela, token_transaccion, fecha_pago)
     VALUES (?, ?, ?, ?, ?, ?, NOW())`,
    [idPedido, idTipoPago, idEstado, monto, pasarela, token.slice(0, 255)],
  );
}

/** El pago ya está guardado en la app: si Nortfarma no responde, queda en el registro para revisarlo. */
async function informarPagoANortfarma(idVenta, pasarela, idTransaccion) {
  try {
    await core.registrarPagoVenta(idVenta, { pasarela, id_transaccion: idTransaccion });
  } catch (error) {
    logger.error("No se pudo informar el pago a Nortfarma: revisar a mano", { idVenta, error: error.message });
  }
}

function subtotalDe(lineas) {
  return redondear(lineas.reduce((s, l) => s + redondear(l.precio * l.cantidad), 0));
}

function numeroPedido(id) {
  return `#${String(id).padStart(5, "0")}`;
}

function lineaAJson(l) {
  return {
    idProducto: l.idProducto,
    nombre: l.nombre,
    presentacion: l.presentacion,
    nombrePresentacion: l.nombrePresentacion,
    precio: l.precio,
    precioRegular: l.precioRegular,
    descuento: l.descuento,
    stock: l.stock,
    cantidad: l.cantidad,
    requiereReceta: l.requiereReceta,
  };
}

module.exports.informarPagoANortfarma = informarPagoANortfarma;
