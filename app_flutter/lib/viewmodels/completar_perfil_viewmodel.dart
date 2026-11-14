import '../core/validadores.dart';
import '../models/usuario.dart';
import '../services/perfil_service.dart';
import 'base_viewmodel.dart';

/// Para cuentas sin perfil (por ejemplo, el primer ingreso con Google):
/// pide los datos que exige la tabla Usuario.
class CompletarPerfilViewModel extends BaseViewModel {
  CompletarPerfilViewModel(this._perfiles);

  final PerfilService _perfiles;

  Usuario? _usuario;

  /// Perfil guardado; null mientras no se haya guardado.
  Usuario? get usuario => _usuario;

  /// Separa "Nombre Apellido1 Apellido2" que trae Google en nombres y apellidos.
  static (String, String) separarNombre(String? nombreVisible) {
    final partes = (nombreVisible ?? '').trim().split(RegExp(r'\s+'));
    if (partes.length < 2) return (partes.join(' '), '');
    if (partes.length == 2) return (partes[0], partes[1]);
    return (partes.sublist(0, partes.length - 2).join(' '), partes.sublist(partes.length - 2).join(' '));
  }

  String? validarNombres(String? v) => Validadores.requerido(v, 'nombre');
  String? validarApellidos(String? v) => Validadores.requerido(v, 'apellido');
  String? validarDni(String? v) => Validadores.dni(v);
  String? validarCelular(String? v) => Validadores.celular(v);

  Future<bool> guardar(DatosPerfil datos) =>
      ejecutar(() async => _usuario = await _perfiles.registrar(datos));
}
