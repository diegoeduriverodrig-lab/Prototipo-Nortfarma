import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/mis_pedidos_viewmodel.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pedido_widgets.dart';
import 'pedido_detalle_view.dart';

/// Historial de pedidos del cliente (RF03).
class MisPedidosView extends StatelessWidget {
  const MisPedidosView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MisPedidosViewModel>();

    Widget cuerpo;
    if (vm.error != null && vm.pedidos.isEmpty) {
      cuerpo = EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pudimos cargar tus pedidos',
        mensaje: vm.error,
        accion: vm.cargar,
      );
    } else if (!vm.cargadoAlgunaVez || (vm.cargando && vm.pedidos.isEmpty)) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (vm.pedidos.isEmpty) {
      cuerpo = EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Aún no tienes pedidos',
        mensaje: 'Cuando compres, aquí verás el estado de cada pedido.',
        accion: () => context.read<NavegacionClienteViewModel>().ir(PestanaCliente.catalogo),
        textoAccion: 'Ver catálogo',
      );
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: vm.cargar,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: vm.pedidos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = vm.pedidos[i];
            return TarjetaPedido(
              pedido: p,
              onTap: () async {
                await Navigator.of(context).push(PedidoDetalleView.ruta(p.idPedido));
                vm.cargar(); // por si cambió el estado mientras tanto
              },
            );
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Mis pedidos')), body: cuerpo);
  }
}
