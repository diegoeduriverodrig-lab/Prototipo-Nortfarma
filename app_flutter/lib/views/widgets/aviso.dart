import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

enum TipoAviso { error, info, exito }

/// Recuadro de mensaje: errores, información o confirmaciones.
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.mensaje,
    this.titulo,
    this.tipo = TipoAviso.error,
  });

  final String mensaje;
  final String? titulo;
  final TipoAviso tipo;

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color color, IconData icono) = switch (tipo) {
      TipoAviso.error => (
        AppColors.rojo.withValues(alpha: 0.08),
        const Color(0xFFC62828),
        Icons.error_outline,
      ),
      TipoAviso.info => (
        AppColors.turquesaClaro,
        AppColors.turquesaOscuro,
        Icons.info_outline,
      ),
      TipoAviso.exito => (
        AppColors.exitoClaro,
        AppColors.exito,
        Icons.verified_user_outlined,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      titulo!,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                Text(
                  mensaje,
                  style: TextStyle(
                    color: tipo == TipoAviso.error ? color : AppColors.texto,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
