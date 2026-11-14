import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/usuario.dart';
import '../viewmodels/sesion_viewmodel.dart';
import 'admin/admin_shell_view.dart';
import 'cliente/cliente_shell_view.dart';
import 'completar_perfil_view.dart';
import 'encargado/encargado_shell_view.dart';
import 'estado_sesion_view.dart';
import 'login_view.dart';
import 'registro_view.dart';
import 'repartidor/repartidor_shell_view.dart';

/// Pantalla de entrada: comprueba la sesión y muestra el Inicio o las opciones
/// para registrarse o iniciar sesión.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    switch (sesion.estado) {
      case EstadoSesion.cargandoPerfil:
        return const CargandoPerfilView();
      case EstadoSesion.perfilIncompleto:
        return const CompletarPerfilView();
      case EstadoSesion.errorPerfil:
        return const ErrorPerfilView();
      case EstadoSesion.conSesion:
        // Cada rol ve solo sus módulos.
        return switch (sesion.usuario!.rol) {
          Rol.cliente => const ClienteShellView(),
          Rol.encargado => const EncargadoShellView(),
          Rol.repartidor => const RepartidorShellView(),
          Rol.administrador => const AdminShellView(),
        };
      case EstadoSesion.comprobando:
      case EstadoSesion.sinSesion:
        break;
    }

    final comprobando = sesion.estado == EstadoSesion.comprobando;

    return Scaffold(
      backgroundColor: AppColors.turquesa,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/images/logo_boticas_felicidad.png',
                width: 280,
                semanticLabel: 'Boticas Felicidad - Nortfarma S.A.C.',
              ),
              const SizedBox(height: 24),
              const Text(
                'PEDIDOS EN LÍNEA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(flex: 3),
              if (comprobando) ...[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Comprobando tu sesión...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ] else
                const _OpcionesAcceso(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionesAcceso extends StatelessWidget {
  const _OpcionesAcceso();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Opcion(
                etiqueta: 'SIN CUENTA',
                accion: 'Registrar usuario',
                onTap: () => Navigator.of(context).push(RegistroView.ruta()),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Colors.white.withValues(alpha: 0.35),
              indent: 12,
              endIndent: 12,
            ),
            Expanded(
              child: _Opcion(
                etiqueta: 'CUENTA ACTIVA',
                accion: 'Iniciar sesión',
                onTap: () => Navigator.of(context).push(LoginView.ruta()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.etiqueta, required this.accion, required this.onTap});

  final String etiqueta;
  final String accion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Text(
              etiqueta,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              accion,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
