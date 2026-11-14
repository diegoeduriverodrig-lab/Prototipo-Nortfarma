import 'dart:convert';
import 'dart:typed_data';

import '../models/pedido.dart';
import 'api_service.dart';

/// Entrega, recetas y registro de pedidos (Sprint 3).
class PedidoService {
  PedidoService(this._api);

  final ApiService _api;

  /// Con el carrito, cada botica indica si tiene stock de todos los productos.
  Future<List<Botica>> obtenerBoticas({List<ItemCarrito>? items}) async {
    final r = await _api.llamar('obtenerBoticas', {if (items != null) 'items': _items(items)});
    return (r['boticas'] as List).map((b) => Botica.desdeJson(b as Map<String, dynamic>)).toList();
  }

  Future<List<Ubigeo>> obtenerUbigeos() async {
    final r = await _api.llamar('obtenerUbigeos');
    return (r['ubigeos'] as List).map((u) => Ubigeo.desdeJson(u as Map<String, dynamic>)).toList();
  }

  Future<List<Direccion>> listarDirecciones() async {
    final r = await _api.llamar('listarDirecciones');
    return (r['direcciones'] as List)
        .map((d) => Direccion.desdeJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<Direccion> guardarDireccion({
    required String idUbigeo,
    required String direccionExacta,
    String? referencia,
    double? latitud,
    double? longitud,
  }) async {
    final r = await _api.llamar('guardarDireccion', {
      'idUbigeo': idUbigeo,
      'direccionExacta': direccionExacta.trim(),
      if (referencia != null && referencia.trim().isNotEmpty) 'referencia': referencia.trim(),
      'latitud': ?latitud,
      'longitud': ?longitud,
    });
    return Direccion.desdeJson(r['direccion'] as Map<String, dynamic>);
  }

  /// Todos los deliverys salen de una botica; el backend revisa que tenga todo el carrito.
  Future<CotizacionEnvio> cotizarEnvio(int idDireccion, List<ItemCarrito> items) async {
    final r = await _api.llamar('cotizarEnvio', {'idDireccion': idDireccion, 'items': _items(items)});
    return CotizacionEnvio.desdeJson(r);
  }

  Future<ValidacionCarrito> validarCarrito(List<ItemCarrito> items) async {
    final r = await _api.llamar('validarCarrito', {'items': _items(items)});
    return ValidacionCarrito.desdeJson(r);
  }

  /// RF14: sube la foto de la receta y devuelve su ruta.
  Future<String> subirReceta(Uint8List bytes, String tipo) async {
    final r = await _api.llamar('subirReceta', {
      'imagenBase64': base64Encode(bytes),
      'tipo': tipo,
    });
    return r['ruta'] as String;
  }

  Future<PedidoRegistrado> registrarPedido({
    required List<ItemCarrito> items,
    required TipoEntrega entrega,
    int? idDireccion,
    int? idBotica,
    required TipoComprobante comprobante,
    String? ruc,
    String? razonSocial,
    required TipoPago tipoPago,
    String? codigoPromocion,
    String? recetaRuta,
    String? tokenCulqi,
  }) async {
    final r = await _api.llamar('registrarPedido', {
      'items': _items(items),
      'entrega': {
        'tipo': entrega.name,
        'idDireccion': ?idDireccion,
        'idBotica': ?idBotica,
      },
      'comprobante': {
        'tipo': comprobante.name,
        if (comprobante == TipoComprobante.factura) 'ruc': ruc,
        if (comprobante == TipoComprobante.factura) 'razonSocial': razonSocial,
      },
      'idTipoPago': tipoPago.id,
      if (codigoPromocion != null && codigoPromocion.trim().isNotEmpty)
        'codigoPromocion': codigoPromocion.trim(),
      'recetaRuta': ?recetaRuta,
      'tokenCulqi': ?tokenCulqi,
    });
    return PedidoRegistrado.desdeJson(r);
  }

  /// RF13: reintenta el pago en línea de un pedido cuyo cobro fue rechazado.
  Future<ResultadoPago> pagarPedido(int idPedido, {String? tokenCulqi}) async {
    final r = await _api.llamar('pagarPedido', {'idPedido': idPedido, 'tokenCulqi': ?tokenCulqi});
    return ResultadoPago.desdeJson(r);
  }

  /// Solo se envían id, presentación y cantidad: el backend pone precios y stock.
  static List<Map<String, Object>> _items(List<ItemCarrito> items) => [
    for (final i in items)
      {'idProducto': i.idProducto, 'presentacion': i.presentacion.valor, 'cantidad': i.cantidad},
  ];
}
