import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Foto elegida por el usuario, lista para subir.
class ImagenElegida {
  const ImagenElegida({required this.bytes, required this.tipo});
  final Uint8List bytes;

  /// "image/jpeg" o "image/png".
  final String tipo;
}

enum OrigenImagen { camara, galeria }

/// Toma o elige fotos (receta médica, foto de producto, evidencia de entrega)
/// y las reduce para subirlas.
class ImagenService {
  ImagenService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Devuelve null si el usuario canceló. Por defecto, 1600 px: suficiente para leer
  /// una receta y la imagen queda por debajo de 1 MB; para productos basta con menos.
  Future<ImagenElegida?> elegir(OrigenImagen origen, {double anchoMaximo = 1600}) async {
    final archivo = await _picker.pickImage(
      source: origen == OrigenImagen.camara ? ImageSource.camera : ImageSource.gallery,
      maxWidth: anchoMaximo,
      imageQuality: 75,
    );
    if (archivo == null) return null;
    final bytes = await archivo.readAsBytes();
    final esPng = archivo.name.toLowerCase().endsWith('.png');
    return ImagenElegida(bytes: bytes, tipo: esPng ? 'image/png' : 'image/jpeg');
  }
}
