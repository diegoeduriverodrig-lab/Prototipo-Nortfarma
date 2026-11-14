import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Mensaje centrado para listas vacías, errores o secciones en construcción.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
    this.textoAccion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final VoidCallback? accion;
  final String? textoAccion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppColors.turquesa),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 6),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSecundario),
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: accion, child: Text(textoAccion ?? 'Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
