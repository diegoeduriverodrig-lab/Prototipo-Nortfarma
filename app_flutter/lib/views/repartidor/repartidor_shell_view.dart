import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/seguimiento_service.dart';
import '../../viewmodels/entregas_viewmodel.dart';
import '../cliente/perfil_view.dart';
import 'entregas_view.dart';

/// Estructura del Repartidor: Entregas y Perfil.
class RepartidorShellView extends StatefulWidget {
  const RepartidorShellView({super.key});

  @override
  State<RepartidorShellView> createState() => _RepartidorShellViewState();
}

class _RepartidorShellViewState extends State<RepartidorShellView> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EntregasViewModel(context.read<SeguimientoService>()),
      child: Scaffold(
        body: IndexedStack(index: _pestana, children: const [EntregasView(), PerfilView()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining),
              label: 'Entregas',
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
