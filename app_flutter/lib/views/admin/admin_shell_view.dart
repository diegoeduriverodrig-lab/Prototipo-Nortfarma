import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/imagen_service.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../cliente/perfil_view.dart';
import 'panel_admin_view.dart';
import 'pedidos_admin_view.dart';
import 'personal_view.dart';
import 'productos_admin_view.dart';

/// Estructura del Administrador (Figura 12): Panel, Pedidos, Personal, Catálogo y Perfil.
class AdminShellView extends StatefulWidget {
  const AdminShellView({super.key});

  @override
  State<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends State<AdminShellView> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PanelAdminViewModel(admin)),
        ChangeNotifierProvider(create: (_) => PedidosAdminViewModel(admin)),
        ChangeNotifierProvider(create: (_) => PersonalViewModel(admin)),
        ChangeNotifierProvider(
          create: (context) => ProductosAdminViewModel(admin, context.read<ImagenService>()),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _pestana,
          children: const [
            PanelAdminView(),
            PedidosAdminView(),
            PersonalView(),
            ProductosAdminView(),
            PerfilView(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Panel',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Personal',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Catálogo',
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
