import '../models/pedido.dart';
import '../services/culqi_service.dart';
import '../services/pedido_service.dart';
import 'base_viewmodel.dart';

/// Reintento del pago en línea de un pedido cuyo cobro fue rechazado (RF13).
class PagarPedidoViewModel extends BaseViewModel {
  PagarPedidoViewModel(this._pedidos, this._culqi, {required this.idPedido, required this.numero, required this.total});

  final PedidoService _pedidos;
  final CulqiService _culqi;
  final int idPedido;
  final String numero;
  final double total;

  ResultadoPago? _resultado;
  String? _errorTarjeta;

  ResultadoPago? get resultado => _resultado;

  /// Error de la tarjeta (datos inválidos o rechazo del banco).
  String? get errorTarjeta => _errorTarjeta;

  bool get pedirTarjeta => _culqi.habilitado;

  Future<bool> pagar(DatosTarjeta? tarjeta) async {
    _errorTarjeta = null;
    final ok = await ejecutar(() async {
      String? token;
      if (pedirTarjeta) {
        try {
          token = await _culqi.crearToken(tarjeta!);
        } on CulqiException catch (e) {
          _errorTarjeta = e.mensaje;
          return;
        }
      }
      _resultado = await _pedidos.pagarPedido(idPedido, tokenCulqi: token);
      if (!_resultado!.aprobado) _errorTarjeta = _resultado!.mensaje ?? 'La tarjeta fue rechazada.';
    });
    notifyListeners();
    return ok && (_resultado?.aprobado ?? false);
  }
}
