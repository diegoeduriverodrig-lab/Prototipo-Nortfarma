import 'dart:convert';
import 'dart:typed_data';

import '../models/seguimiento.dart';
import 'api_service.dart';

/// Consulta de pedidos (RF03) y gestión del Encargado de botica (Sprint 4).
class SeguimientoService {
  SeguimientoService(this._api);

  final ApiService _api;

  Future<List<PedidoResumen>> misPedidos() async {
    final r = await _api.llamar('misPedidos');
    return (r['pedidos'] as List)
        .map((p) => PedidoResumen.desdeJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PedidoDetalle> obtenerPedido(int idPedido) async {
    final r = await _api.llamar('obtenerPedido', {'idPedido': idPedido});
    return PedidoDetalle.desdeJson(r['pedido'] as Map<String, dynamic>);
  }

  // ---- Encargado de botica ----

  Future<Bandeja> bandeja({int? idEstado}) async {
    final r = await _api.llamar('bandejaPedidos', {'idEstado': ?idEstado});
    return Bandeja.desdeJson(r);
  }

  Future<void> actualizarEstado(
    int idPedido,
    int idEstado, {
    String? motivo,
    String? dniCliente,
  }) => _api.llamar('actualizarEstadoPedido', {
    'idPedido': idPedido,
    'idEstado': idEstado,
    'motivo': ?motivo,
    'dniCliente': ?dniCliente,
  });

  Future<List<Repartidor>> listarRepartidores() async {
    final r = await _api.llamar('listarRepartidores');
    return (r['repartidores'] as List)
        .map((p) => Repartidor.desdeJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> asignarRepartidor(int idPedido, int idRepartidor) =>
      _api.llamar('asignarRepartidor', {'idPedido': idPedido, 'idRepartidor': idRepartidor});

  // ---- Repartidor ----

  Future<Entregas> misEntregas() async => Entregas.desdeJson(await _api.llamar('misEntregas'));

  /// Al entregar: [evidenciaRuta] (foto, obligatoria), ubicación GPS y observación.
  Future<void> actualizarEntrega(
    int idPedido,
    int idEstado, {
    String? motivo,
    String? detalle,
    String? evidenciaRuta,
    double? latitud,
    double? longitud,
    String? observacion,
  }) => _api.llamar('actualizarEntrega', {
    'idPedido': idPedido,
    'idEstado': idEstado,
    'motivo': ?motivo,
    'detalle': ?detalle,
    'evidenciaRuta': ?evidenciaRuta,
    'latitud': ?latitud,
    'longitud': ?longitud,
    'observacion': ?observacion,
  });

  /// Sube la foto de la entrega y devuelve su ruta (`evidencias/<id>.jpg`).
  Future<String> subirEvidencia(Uint8List bytes, String tipo) async {
    final r = await _api.llamar('subirEvidencia', {'imagenBase64': base64Encode(bytes), 'tipo': tipo});
    return r['ruta'] as String;
  }

  /// Problema que no termina la entrega (retraso, cliente no responde...).
  Future<void> reportarIncidencia(int idPedido, String tipo, {String? detalle}) =>
      _api.llamar('reportarIncidencia', {'idPedido': idPedido, 'tipo': tipo, 'detalle': ?detalle});
}
