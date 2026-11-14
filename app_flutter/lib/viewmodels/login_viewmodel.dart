import '../core/validadores.dart';
import '../services/auth_service.dart';
import 'base_viewmodel.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel(this._auth);

  final AuthService _auth;

  bool _ocultarContrasena = true;
  bool get ocultarContrasena => _ocultarContrasena;

  void alternarContrasena() {
    _ocultarContrasena = !_ocultarContrasena;
    notifyListeners();
  }

  String? validarCorreo(String? v) => Validadores.correo(v);
  String? validarContrasena(String? v) =>
      Validadores.requerido(v, 'contraseña');

  Future<bool> iniciarSesion(String correo, String contrasena) =>
      ejecutar(() => _auth.iniciarSesion(correo, contrasena));

  /// Devuelve true solo si la sesión con Google se completó.
  Future<bool> iniciarConGoogle() async {
    var completado = false;
    final ok = await ejecutar(() async {
      completado = await _auth.iniciarConGoogle();
    });
    return ok && completado;
  }
}
