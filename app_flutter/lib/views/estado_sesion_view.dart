import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../viewmodels/sesion_viewmodel.dart';
import 'widgets/estado_vacio.dart';

/// Mientras se obtiene el perfil del usuario desde la API.
class CargandoPerfilView extends StatelessWidget {
  const CargandoPerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.turquesa),
            SizedBox(height: 16),
            Text('Cargando tu cuenta...', style: TextStyle(color: AppColors.textoSecundario)),
          ],
        ),
      ),
    );
  }
}

/// Cuando no se pudo obtener el perfil (servidor apagado, sin internet).
class ErrorPerfilView extends StatelessWidget {
  const ErrorPerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EstadoVacio(
                icono: Icons.cloud_off_outlined,
                titulo: 'No pudimos cargar tu cuenta',
                mensaje: sesion.error,
                accion: sesion.recargarPerfil,
                textoAccion: 'Reintentar',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton(
                onPressed: sesion.cerrarSesion,
                child: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
