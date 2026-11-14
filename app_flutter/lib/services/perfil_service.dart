import '../models/usuario.dart';
import 'api_service.dart';

/// Perfil del usuario en MySQL (a través de la API).
class PerfilService {
  PerfilService(this._api);

  final ApiService _api;

  /// Devuelve el perfil con su rol, o null si aún no lo ha completado.
  Future<Usuario?> obtener() async {
    final r = await _api.llamar('obtenerPerfil');
    if (r['registrado'] != true) return null;
    return Usuario.desdeJson(r['perfil'] as Map<String, dynamic>);
  }

  /// RF16: guarda DNI, celular y nombres. El backend asigna siempre el rol Cliente.
  Future<Usuario> registrar(DatosPerfil datos) async {
    final r = await _api.llamar('registrarPerfil', datos.aJson());
    return Usuario.desdeJson(r['perfil'] as Map<String, dynamic>);
  }
}
