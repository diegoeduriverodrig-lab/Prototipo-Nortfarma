import '../core/validadores.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/perfil_service.dart';
import 'base_viewmodel.dart';

/// Registro público: siempre crea cuentas de Cliente.
/// Las cuentas del personal las crea el Administrador.
class RegistroViewModel extends BaseViewModel {
  RegistroViewModel(this._auth, this._perfiles);

  final AuthService _auth;
  final PerfilService _perfiles;

  bool _aceptaTerminos = false;
  bool _ocultarContrasena = true;
  bool _mostrarAvisoTerminos = false;
  Usuario? _usuarioRegistrado;
  String? _avisoPerfil;

  bool get aceptaTerminos => _aceptaTerminos;
  bool get ocultarContrasena => _ocultarContrasena;
  bool get mostrarAvisoTerminos => _mostrarAvisoTerminos;

  /// Perfil guardado en MySQL tras registrarse.
  Usuario? get usuarioRegistrado => _usuarioRegistrado;

  /// Si la cuenta se creó pero el perfil no se pudo guardar, el motivo.
  /// El usuario lo completará en la pantalla "Completa tu perfil".
  String? get avisoPerfil => _avisoPerfil;

  void cambiarTerminos(bool valor) {
    _aceptaTerminos = valor;
    if (valor) _mostrarAvisoTerminos = false;
    notifyListeners();
  }

  void alternarContrasena() {
    _ocultarContrasena = !_ocultarContrasena;
    notifyListeners();
  }

  String? validarNombres(String? v) => Validadores.requerido(v, 'nombre');
  String? validarApellidos(String? v) => Validadores.requerido(v, 'apellido');
  String? validarDni(String? v) => Validadores.dni(v);
  String? validarCelular(String? v) => Validadores.celular(v);
  String? validarCorreo(String? v) => Validadores.correo(v);
  String? validarContrasena(String? v) => Validadores.contrasena(v);
  String? validarConfirmacion(String? v, String original) =>
      Validadores.confirmarContrasena(v, original);

  /// Crea la cuenta en Firebase y luego guarda el perfil en MySQL (rol Cliente).
  /// Devuelve true si la cuenta se creó, aunque el perfil quede pendiente.
  Future<bool> registrar(DatosRegistro datos) async {
    if (!_aceptaTerminos) {
      _mostrarAvisoTerminos = true;
      notifyListeners();
      return false;
    }
    return ejecutar(() async {
      final p = datos.perfil;
      await _auth.crearCuenta(
        datos.correo,
        datos.contrasena,
        '${p.nombres.trim()} ${p.apellidos.trim()}',
      );
      try {
        _usuarioRegistrado = await _perfiles.registrar(p);
      } on ApiException catch (e) {
        _avisoPerfil = e.mensaje;
      }
    });
  }
}
