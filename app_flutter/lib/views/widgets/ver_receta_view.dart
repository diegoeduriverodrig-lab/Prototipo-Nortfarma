import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';

/// Foto de la receta médica que adjuntó el cliente (RF14). Solo se muestra: no se valida.
class VerRecetaView {
  static Route<void> ruta({required String rutaReceta, required String numeroPedido}) =>
      VerImagenView.ruta(titulo: 'Receta · Pedido $numeroPedido', url: Config.urlReceta(rutaReceta));
}

/// Foto a pantalla completa, con zoom (receta médica, evidencia de entrega...).
class VerImagenView extends StatelessWidget {
  const VerImagenView({super.key, required this.titulo, required this.url});

  static Route<void> ruta({required String titulo, required String url}) =>
      MaterialPageRoute(builder: (_) => VerImagenView(titulo: titulo, url: url));

  final String titulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: Text(titulo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progreso) => progreso == null
                    ? child
                    : const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('No se pudo cargar la imagen')),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pellizca la imagen para ampliarla.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}
