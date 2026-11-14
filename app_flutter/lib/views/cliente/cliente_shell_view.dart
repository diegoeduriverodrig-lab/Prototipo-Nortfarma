import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/catalogo_service.dart';
import '../../services/seguimiento_service.dart';
import '../../viewmodels/carrito_viewmodel.dart';
import '../../viewmodels/catalogo_viewmodel.dart';
import '../../viewmodels/inicio_viewmodel.dart';
import '../../viewmodels/mis_pedidos_viewmodel.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import 'carrito_view.dart';
import 'catalogo_view.dart';
import 'inicio_view.dart';
import 'mis_pedidos_view.dart';
import 'perfil_view.dart';

/// Estructura principal del cliente con la barra de navegación inferior.
class ClienteShellView extends StatefulWidget {
  const ClienteShellView({super.key});

  @override
  State<ClienteShellView> createState() => _ClienteShellViewState();
}

class _ClienteShellViewState extends State<ClienteShellView> {
  late final NavegacionClienteViewModel _navegacion;
  late final InicioViewModel _inicio;
  late final CatalogoViewModel _catalogo;
  late final MisPedidosViewModel _misPedidos;

  @override
  void initState() {
    super.initState();
    final catalogo = context.read<CatalogoService>();
    _inicio = InicioViewModel(catalogo);
    _catalogo = CatalogoViewModel(catalogo);
    _misPedidos = MisPedidosViewModel(context.read<SeguimientoService>());
    _navegacion = context.read<NavegacionClienteViewModel>()
      ..reiniciar()
      ..addListener(_alCambiarPestana);
  }

  /// Mis pedidos se actualiza cada vez que se abre (los estados cambian en la botica).
  void _alCambiarPestana() {
    if (_navegacion.actual == PestanaCliente.pedidos) _misPedidos.cargar();
  }

  @override
  void dispose() {
    _navegacion.removeListener(_alCambiarPestana);
    _inicio.dispose();
    _catalogo.dispose();
    _misPedidos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navegacion = context.watch<NavegacionClienteViewModel>();
    final unidades = context.select<CarritoViewModel, int>((c) => c.cantidadTotal);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _inicio),
        ChangeNotifierProvider.value(value: _catalogo),
        ChangeNotifierProvider.value(value: _misPedidos),
      ],
      child: Scaffold(
        // IndexedStack conserva el estado de cada pestaña (búsqueda, scroll).
        body: IndexedStack(
          index: navegacion.actual.index,
          children: [
            InicioView(
              onAbrirCatalogo: ({termino = '', idCategoria}) {
                _catalogo.aplicar(termino: termino, idCategoria: idCategoria);
                navegacion.ir(PestanaCliente.catalogo);
              },
            ),
            const CatalogoView(),
            const MisPedidosView(),
            const CarritoView(),
            const PerfilView(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navegacion.actual.index,
          onDestinationSelected: (i) => navegacion.ir(PestanaCliente.values[i]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Categorías',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Mis pedidos',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unidades > 0,
                label: Text('$unidades'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unidades > 0,
                label: Text('$unidades'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: 'Carrito',
            ),
            const NavigationDestination(
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
