import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración de entornos.
class Config {
  /// En depuración la app usa la API local (emulador de Cloud Functions).
  static const usarEmuladorApi = kDebugMode;

  /// Desde el emulador de Android, la PC se alcanza en 10.0.2.2.
  /// En un celular físico, poner aquí la IP de la PC en la red Wi-Fi.
  static const hostEmuladorApi = '10.0.2.2';
  static const puertoEmuladorApi = 5001;
  static const regionApi = 'us-central1';

  /// Servidor de la API en AWS Lightsail (la usa el APK final, no la depuración).
  /// Se puede cambiar al compilar con --dart-define=API_URL=https://.../api
  static const urlServidorApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://18-216-123-40.sslip.io/api',
  );
  static bool get usarServidorApi => !usarEmuladorApi && urlServidorApi.isNotEmpty;

  // Claves de APIs externas. Llegan desde config/claves.json con:
  //   flutter run --dart-define-from-file=config/claves.json
  // (o con F5 en VS Code, que ya lo incluye). Si están vacías, la función se desactiva.

  /// Google Maps (mapa para marcar la dirección y ver el destino del repartidor).
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static bool get mapsHabilitado => mapsApiKey.isNotEmpty;

  /// Culqi, llave PÚBLICA de prueba (pk_test_...). La secreta solo vive en el backend.
  static const culqiLlavePublica = String.fromEnvironment('CULQI_PUBLIC_KEY');
  static bool get culqiHabilitado => culqiLlavePublica.isNotEmpty;

  /// URL de una función HTTP (por ejemplo, verReceta).
  static String urlFuncion(String nombre) {
    if (usarServidorApi) return '$urlServidorApi/$nombre';
    final proyecto = Firebase.app().options.projectId;
    return usarEmuladorApi
        ? 'http://$hostEmuladorApi:$puertoEmuladorApi/$proyecto/$regionApi/$nombre'
        : 'https://$regionApi-$proyecto.cloudfunctions.net/$nombre';
  }

  /// Imagen de una receta a partir de su ruta guardada (`recetas/<id>.jpg`).
  static String urlReceta(String ruta) =>
      '${urlFuncion('verReceta')}?ruta=${Uri.encodeQueryComponent(ruta)}';

  /// Foto de un producto o evidencia de entrega. Puede ser un enlace (http/https)
  /// o una foto subida a la app (`productos/<id>.jpg`, `evidencias/<id>.jpg`).
  static String urlImagen(String ruta) => ruta.startsWith('http')
      ? ruta
      : '${urlFuncion('verImagen')}?ruta=${Uri.encodeQueryComponent(ruta)}';
}
