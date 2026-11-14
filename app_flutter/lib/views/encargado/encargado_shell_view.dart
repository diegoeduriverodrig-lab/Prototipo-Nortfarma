import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/seguimiento_service.dart';
import '../../viewmodels/bandeja_viewmodel.dart';
import '../cliente/perfil_view.dart';
import 'bandeja_view.dart';

/// Estructura del Encargado de botica: Bandeja de pedidos y Perfil.
class EncargadoShellView extends StatefulWidget {
  const EncargadoShellView({super.key});

  @override
  State<EncargadoShellView> createState() => _EncargadoShellViewState();
}

class _EncargadoShellViewState extends State<EncargadoShellView> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BandejaViewModel(context.read<SeguimientoService>()),
      child: Scaffold(
        body: IndexedStack(index: _pestana, children: const [BandejaView(), PerfilView()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Bandeja',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
