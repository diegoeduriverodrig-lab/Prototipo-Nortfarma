import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/seguimiento.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../cliente/pedido_detalle_view.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pedido_widgets.dart';

/// Consulta de pedidos de todas las boticas (solo lectura).
class PedidosAdminView extends StatelessWidget {
  const PedidosAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidosAdminViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Todos los pedidos'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: vm.idEstado == null,
                    onSelected: (_) => vm.filtrar(null),
                  ),
                ),
                for (final e in EstadoPedido.todos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.nombre),
                      selected: vm.idEstado == e.id,
                      onSelected: (_) => vm.filtrar(e.id),
                    ),
                  ),
              ],
            ),
          ),
          if (vm.cargando) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: vm.error != null && vm.pedidos.isEmpty
                ? EstadoVacio(
                    icono: Icons.cloud_off_outlined,
                    titulo: 'No pudimos cargar los pedidos',
                    mensaje: vm.error,
                    accion: vm.cargar,
                  )
                : !vm.cargado
                ? const Center(child: CircularProgressIndicator())
                : vm.pedidos.isEmpty
                ? const EstadoVacio(icono: Icons.receipt_long_outlined, titulo: 'No hay pedidos')
                : RefreshIndicator(
                    onRefresh: vm.cargar,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: vm.pedidos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = vm.pedidos[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.botica != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  p.botica!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                                ),
                              ),
                            TarjetaPedido(
                              pedido: p,
                              mostrarCliente: true,
                              onTap: () => Navigator.of(context).push(
                                PedidoDetalleView.ruta(p.idPedido, paraPersonal: true),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
