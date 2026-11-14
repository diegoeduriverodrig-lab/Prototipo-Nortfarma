import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Cabecera turquesa con el logo de Boticas Felicidad y el título de la pantalla.
class EncabezadoMarca extends StatelessWidget {
  const EncabezadoMarca({super.key, required this.titulo, this.subtitulo});

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.of(context).canPop();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.turquesa,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (puedeVolver)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Volver',
                    ),
                  const Spacer(),
                ],
              ),
              Center(
                child: Image.asset(
                  'assets/images/logo_boticas_felicidad.png',
                  height: 64,
                  semanticLabel: 'Boticas Felicidad - Nortfarma S.A.C.',
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'PEDIDOS EN LÍNEA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
