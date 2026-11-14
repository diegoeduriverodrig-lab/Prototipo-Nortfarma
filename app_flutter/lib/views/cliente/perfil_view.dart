import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../viewmodels/sesion_viewmodel.dart';
import '../terminos_view.dart';

/// Perfil del cliente: datos personales y cierre de sesión.
class PerfilView extends StatelessWidget {
  const PerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();
    final usuario = sesion.usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.turquesaClaro,
                child: Text(
                  usuario.primerNombre.isEmpty ? '?' : usuario.primerNombre[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.turquesaOscuro,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      usuario.rol.nombre,
                      style: const TextStyle(color: AppColors.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                _Dato(icono: Icons.mail_outline, etiqueta: 'Correo', valor: usuario.correo),
                _Dato(icono: Icons.badge_outlined, etiqueta: 'DNI', valor: usuario.dni ?? '-'),
                _Dato(
                  icono: Icons.phone_android,
                  etiqueta: 'Celular',
                  valor: usuario.telefono ?? '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Mis direcciones'),
              subtitle: const Text('Próximamente'),
              enabled: false,
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Términos y privacidad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(TerminosView.ruta()),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: sesion.cerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.etiqueta, required this.valor});

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono, color: AppColors.turquesa),
      title: Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      subtitle: Text(valor, style: const TextStyle(fontSize: 15, color: AppColors.texto)),
    );
  }
}
