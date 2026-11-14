import 'package:cloud_functions/cloud_functions.dart';

import '../core/config.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.codigo, this.detalles});
  final String mensaje;
  final String? codigo;

  /// Datos extra del backend (por ejemplo, los productos sin stock).
  final Map<String, dynamic>? detalles;

  @override
  String toString() => mensaje;
}

/// Llama a las Cloud Functions (la API del sistema). Único punto de contacto con el backend.
class ApiService {
  ApiService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance {
    if (Config.usarEmuladorApi) {
      _functions.useFunctionsEmulator(Config.hostEmuladorApi, Config.puertoEmuladorApi);
    }
  }

  final FirebaseFunctions _functions;

  /// Llama a una función y devuelve su respuesta como mapa.
  Future<Map<String, dynamic>> llamar(
    String funcion, [
    Map<String, dynamic> datos = const {},
  ]) async {
    try {
      final opciones = HttpsCallableOptions(timeout: const Duration(seconds: 20));
      // En el APK final, las funciones viven en el servidor de AWS (mismo protocolo).
      final llamable = Config.usarServidorApi
          ? _functions.httpsCallableFromUrl(Config.urlFuncion(funcion), options: opciones)
          : _functions.httpsCallable(funcion, options: opciones);
      final resultado = await llamable.call<Object?>(datos);
      return _aMapa(resultado.data);
    } on FirebaseFunctionsException catch (e) {
      throw ApiException(
        _mensajeDe(e),
        codigo: e.code,
        detalles: e.details is Map ? _aMapa(e.details) : null,
      );
    }
  }

  /// Las respuestas llegan como `Map<Object?, Object?>`; se normalizan a tipos de Dart.
  static Map<String, dynamic> _aMapa(Object? valor) =>
      Map<String, dynamic>.from(_normalizar(valor) as Map? ?? const {});

  static Object? _normalizar(Object? valor) {
    if (valor is Map) {
      return {for (final e in valor.entries) e.key.toString(): _normalizar(e.value)};
    }
    if (valor is List) return valor.map(_normalizar).toList();
    return valor;
  }

  String _mensajeDe(FirebaseFunctionsException e) {
    switch (e.code) {
      // Errores con mensaje pensado para el usuario (los escribe el backend).
      case 'invalid-argument':
      case 'already-exists':
      case 'not-found':
      case 'permission-denied':
      case 'failed-precondition':
      case 'unauthenticated':
        return e.message ?? 'No se pudo completar la acción.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
      default:
        return 'Ocurrió un error en el servidor. Inténtalo de nuevo.';
    }
  }
}
