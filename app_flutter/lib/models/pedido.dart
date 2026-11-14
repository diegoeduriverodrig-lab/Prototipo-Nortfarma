/// Modelos del checkout y los pedidos (Sprint 3).
library;

import 'producto.dart';

double _aDouble(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Producto en el carrito, en una presentación (caja, blíster o unidad).
/// Se guarda en el celular (RNF07).
class ItemCarrito {
  const ItemCarrito({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    required this.requiereReceta,
    required this.stock,
    required this.cantidad,
    this.presentacion = TipoPresentacion.empaque,
    this.nombrePresentacion = '',
    double? precioRegular,
  }) : precioRegular = precioRegular ?? precio;

  factory ItemCarrito.desdeJson(Map<String, dynamic> json) => ItemCarrito(
    idProducto: json['idProducto'] as int,
    nombre: json['nombre'] as String,
    presentacion: TipoPresentacion.desde(json['presentacion'] as String?),
    nombrePresentacion: json['nombrePresentacion'] as String? ?? '',
    precio: _aDouble(json['precio']),
    precioRegular: (json['precioRegular'] as num?)?.toDouble(),
    requiereReceta: json['requiereReceta'] as bool? ?? false,
    stock: json['stock'] as int? ?? 0,
    cantidad: json['cantidad'] as int,
  );

  final int idProducto;
  final String nombre;
  final TipoPresentacion presentacion;

  /// "Caja x 100 tabletas", "Blíster x 10" o "Unidad".
  final String nombrePresentacion;

  /// Precio unitario de referencia (con descuento): el backend confirma el real al registrar el pedido.
  final double precio;
  final double precioRegular;
  final bool requiereReceta;
  final int stock;
  final int cantidad;

  /// Identifica la línea: el mismo producto puede estar en caja y en unidades.
  String get clave => claveDe(idProducto, presentacion);
  static String claveDe(int idProducto, TipoPresentacion presentacion) => '$idProducto|${presentacion.valor}';

  double get subtotal => precio * cantidad;
  bool get sinStockSuficiente => cantidad > stock;
  bool get conDescuento => precioRegular > precio;

  ItemCarrito copiar({double? precio, double? precioRegular, int? stock, int? cantidad}) => ItemCarrito(
    idProducto: idProducto,
    nombre: nombre,
    presentacion: presentacion,
    nombrePresentacion: nombrePresentacion,
    precio: precio ?? this.precio,
    precioRegular: precioRegular ?? (precio == null ? this.precioRegular : null),
    requiereReceta: requiereReceta,
    stock: stock ?? this.stock,
    cantidad: cantidad ?? this.cantidad,
  );

  Map<String, dynamic> aJson() => {
    'idProducto': idProducto,
    'nombre': nombre,
    'presentacion': presentacion.valor,
    'nombrePresentacion': nombrePresentacion,
    'precio': precio,
    'precioRegular': precioRegular,
    'requiereReceta': requiereReceta,
    'stock': stock,
    'cantidad': cantidad,
  };
}

/// Línea validada por el backend: precio, descuento y stock actuales.
class LineaValidada {
  const LineaValidada({
    required this.idProducto,
    required this.precio,
    required this.stock,
    this.presentacion = TipoPresentacion.empaque,
    this.precioRegular,
  });

  factory LineaValidada.desdeJson(Map<String, dynamic> json) => LineaValidada(
    idProducto: json['idProducto'] as int,
    presentacion: TipoPresentacion.desde(json['presentacion'] as String?),
    precio: (json['precio'] as num?)?.toDouble(),
    precioRegular: (json['precioRegular'] as num?)?.toDouble(),
    stock: json['stock'] as int? ?? 0,
  );

  final int idProducto;
  final TipoPresentacion presentacion;
  final double? precio;
  final double? precioRegular;
  final int stock;

  String get clave => ItemCarrito.claveDe(idProducto, presentacion);
}

class ValidacionCarrito {
  const ValidacionCarrito({required this.lineas, required this.sinStock});

  factory ValidacionCarrito.desdeJson(Map<String, dynamic> json) => ValidacionCarrito(
    lineas: (json['items'] as List)
        .map((i) => LineaValidada.desdeJson(i as Map<String, dynamic>))
        .toList(),
    sinStock: (json['sinStock'] as List)
        .map((i) => (i as Map<String, dynamic>)['nombre'] as String)
        .toList(),
  );

  final List<LineaValidada> lineas;

  /// Nombres de los productos sin stock suficiente.
  final List<String> sinStock;
}

class Botica {
  const Botica({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.horario,
    this.tieneStock = true,
    this.productosSinStock = const [],
  });

  factory Botica.desdeJson(Map<String, dynamic> json) => Botica(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    direccion: json['direccion'] as String,
    horario: json['horario'] as String? ?? '',
    tieneStock: json['tieneStock'] as bool? ?? true,
    productosSinStock: (json['productosSinStock'] as List?)?.cast<String>() ?? const [],
  );

  final int id;
  final String nombre;
  final String direccion;

  /// "Lun-Sáb 7:00 a. m. - 11:00 p. m. · Dom y feriados ..."
  final String horario;

  /// Si tiene stock de todo el carrito (para recojo en tienda).
  final bool tieneStock;
  final List<String> productosSinStock;
}

class Ubigeo {
  const Ubigeo({required this.id, required this.distrito, required this.provincia});

  factory Ubigeo.desdeJson(Map<String, dynamic> json) => Ubigeo(
    id: json['id'] as String,
    distrito: json['distrito'] as String,
    provincia: json['provincia'] as String,
  );

  final String id;
  final String distrito;
  final String provincia;
}

/// Dirección de entrega del cliente (tabla Direccion_Cliente).
class Direccion {
  const Direccion({
    required this.id,
    required this.distrito,
    required this.direccionExacta,
    this.referencia,
  });

  factory Direccion.desdeJson(Map<String, dynamic> json) => Direccion(
    id: json['id'] as int,
    distrito: json['distrito'] as String,
    direccionExacta: json['direccionExacta'] as String,
    referencia: json['referencia'] as String?,
  );

  final int id;
  final String distrito;
  final String direccionExacta;
  final String? referencia;
}

class CotizacionEnvio {
  const CotizacionEnvio({required this.costo, required this.distanciaKm, required this.botica});

  factory CotizacionEnvio.desdeJson(Map<String, dynamic> json) => CotizacionEnvio(
    costo: _aDouble(json['costoEnvio']),
    distanciaKm: _aDouble(json['distanciaKm']),
    botica: Botica.desdeJson(json['botica'] as Map<String, dynamic>),
  );

  final double costo;
  final double distanciaKm;

  /// Botica que despacha todos los deliverys (Av. Country).
  final Botica botica;
}

enum TipoEntrega { delivery, recojo }

enum TipoComprobante { boleta, factura }

/// Métodos de pago (tabla Tipo_Pago).
enum TipoPago {
  tarjeta(1, 'Tarjeta (en línea)', true),
  yapePlin(2, 'Yape / Plin (en línea)', true),
  pos(3, 'Contraentrega con POS', false),
  efectivo(4, 'Contraentrega en efectivo', false);

  const TipoPago(this.id, this.nombre, this.enLinea);
  final int id;
  final String nombre;
  final bool enLinea;
}

/// Respuesta de registrarPedido.
class PedidoRegistrado {
  const PedidoRegistrado({
    required this.idPedido,
    required this.numero,
    required this.estadoPedido,
    required this.estadoPago,
    required this.tipoEntrega,
    required this.botica,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    this.comprobante,
    this.mensajePago,
  });

  factory PedidoRegistrado.desdeJson(Map<String, dynamic> json) => PedidoRegistrado(
    idPedido: json['idPedido'] as int,
    numero: json['numero'] as String,
    comprobante: json['comprobante'] as String?,
    estadoPedido: json['estadoPedido'] as String,
    estadoPago: json['estadoPago'] as String,
    tipoEntrega: json['tipoEntrega'] as String,
    botica: Botica.desdeJson(json['botica'] as Map<String, dynamic>),
    subtotal: _aDouble(json['subtotal']),
    costoEnvio: _aDouble(json['costoEnvio']),
    total: _aDouble(json['total']),
    mensajePago: json['mensajePago'] as String?,
  );

  final int idPedido;
  final String numero;

  /// Serie-correlativo asignado por Nortfarma (B901-00000001).
  final String? comprobante;
  final String estadoPedido;

  /// "Pagado", "Por pagar" o "Fallido" (tarjeta rechazada: se puede reintentar).
  final String estadoPago;

  /// Motivo del rechazo devuelto por la pasarela.
  final String? mensajePago;
  final String tipoEntrega;
  final Botica botica;
  final double subtotal;
  final double costoEnvio;
  final double total;

  bool get pagoRechazado => estadoPago == 'Fallido';
}

/// Resultado de un intento de pago (pagarPedido).
class ResultadoPago {
  const ResultadoPago({required this.estadoPago, this.mensaje});

  factory ResultadoPago.desdeJson(Map<String, dynamic> json) => ResultadoPago(
    estadoPago: json['estadoPago'] as String,
    mensaje: json['mensajePago'] as String?,
  );

  final String estadoPago;
  final String? mensaje;

  bool get aprobado => estadoPago == 'Pagado';
}

/// Punto elegido en el mapa para una dirección de entrega (RF02).
class UbicacionElegida {
  const UbicacionElegida({
    required this.latitud,
    required this.longitud,
    this.direccionSugerida,
    this.distritoSugerido,
  });

  final double latitud;
  final double longitud;

  /// Calle y número obtenidos por geocodificación inversa (puede faltar).
  final String? direccionSugerida;
  final String? distritoSugerido;
}
