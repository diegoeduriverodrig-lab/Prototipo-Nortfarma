import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/perfil_service.dart';

enum EstadoSesion {
  /// Arrancando: aún no se sabe si hay sesión.
  comprobando,
  sinSesion,

  /// Hay cuenta de Firebase; se está pidiendo el perfil a la API.
  cargandoPerfil,

  /// Cuenta sin perfil (p. ej. primer ingreso con Google): debe completar sus datos.
  perfilIncompleto,

  /// No se pudo obtener el perfil (servidor caído, sin internet).
  errorPerfil,
  conSesion,
}

/// Escucha la sesión de Firebase, obtiene el perfil y rol desde la API
/// y decide qué pantalla ve el usuario.
class SesionViewModel extends ChangeNotifier {
  SesionViewModel(this._auth, this._perfiles) {
    _sub = _auth.cambiosDeSesion.listen(_alCambiarCuenta);
  }

  final AuthService _auth;
  final PerfilService _perfiles;
  late final StreamSubscription<CuentaFirebase?> _sub;

  EstadoSesion _estado = EstadoSesion.comprobando;
  CuentaFirebase? _cuenta;
  Usuario? _usuario;
  String? _error;

  /// Evita que una respuesta antigua pise a una más reciente.
  int _peticion = 0;

  EstadoSesion get estado => _estado;
  CuentaFirebase? get cuenta => _cuenta;
  Usuario? get usuario => _usuario;
  String? get error => _error;

  Future<void> _alCambiarCuenta(CuentaFirebase? cuenta) async {
    _cuenta = cuenta;
    if (cuenta == null) {
      _peticion++;
      _usuario = null;
      _cambiar(EstadoSesion.sinSesion);
      return;
    }
    await recargarPerfil();
  }

  /// Vuelve a pedir el perfil (tras registrarse, completar datos o un error).
  Future<void> recargarPerfil() async {
    if (_cuenta == null) return;
    final peticion = ++_peticion;
    _error = null;
    _cambiar(EstadoSesion.cargandoPerfil);
    try {
      final usuario = await _perfiles.obtener();
      if (peticion != _peticion) return;
      _usuario = usuario;
      _cambiar(usuario == null ? EstadoSesion.perfilIncompleto : EstadoSesion.conSesion);
    } on ApiException catch (e) {
      if (peticion != _peticion) return;
      _error = e.mensaje;
      _cambiar(EstadoSesion.errorPerfil);
    }
  }

  /// Usado al completar el perfil: ya se tiene el usuario, no hace falta pedirlo.
  void establecerUsuario(Usuario usuario) {
    _peticion++;
    _usuario = usuario;
    _cambiar(EstadoSesion.conSesion);
  }

  Future<void> cerrarSesion() => _auth.cerrarSesion();

  void _cambiar(EstadoSesion estado) {
    _estado = estado;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
