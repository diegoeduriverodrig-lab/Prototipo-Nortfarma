import '../core/validadores.dart';
import '../services/auth_service.dart';
import 'base_viewmodel.dart';

class RecuperarViewModel extends BaseViewModel {
  RecuperarViewModel(this._auth);

  final AuthService _auth;

  String? _correoEnviado;

  /// Correo al que se envió el enlace; null mientras no se haya enviado.
  String? get correoEnviado => _correoEnviado;

  String? validarCorreo(String? v) => Validadores.correo(v);

  Future<void> enviar(String correo) async {
    final ok = await ejecutar(() => _auth.enviarRecuperacion(correo));
    if (ok) {
      _correoEnviado = correo.trim();
      notifyListeners();
    }
  }

  void volverAIntentar() {
    _correoEnviado = null;
    notifyListeners();
  }
}
