import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../models/seguimiento.dart';
import '../../viewmodels/entregas_viewmodel.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pedido_widgets.dart';
import 'entrega_detalle_view.dart';

/// Entregas asignadas al repartidor: en curso y recientes.
class EntregasView extends StatelessWidget {
  const EntregasView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EntregasViewModel>();
    final entregas = vm.entregas;

    Future<void> abrir(PedidoResumen p) async {
      await Navigator.of(context).push(
        EntregaDetalleView.ruta(
          p.idPedido,
          motivosFallo: entregas?.motivosFallo ?? const [],
          tiposIncidencia: entregas?.tiposIncidencia ?? const [],
        ),
      );
      vm.cargar();
    }

    Widget cuerpo;
    if (entregas == null) {
      cuerpo = vm.error != null
          ? EstadoVacio(
              icono: Icons.cloud_off_outlined,
              titulo: 'No pudimos cargar tus entregas',
              mensaje: vm.error,
              accion: vm.cargar,
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: vm.cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'En curso (${entregas.activas.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (entregas.activas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EstadoVacio(
                  icono: Icons.inventory_2_outlined,
                  titulo: 'Sin entregas asignadas',
                  mensaje: 'Cuando la botica te asigne un pedido aparecerá aquí.',
                ),
              ),
            for (final p in entregas.activas) ...[
              _TarjetaEntrega(pedido: p, onTap: () => abrir(p)),
              const SizedBox(height: 10),
            ],
            if (entregas.recientes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final p in entregas.recientes) ...[
                TarjetaPedido(pedido: p, mostrarCliente: true, onTap: () => abrir(p)),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Mis entregas'),
        actions: [
          IconButton(
            onPressed: vm.cargando ? null : vm.cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: cuerpo,
    );
  }
}

/// Tarjeta grande con lo que el repartidor necesita: a dónde va y si debe cobrar.
class _TarjetaEntrega extends StatelessWidget {
  const _TarjetaEntrega({required this.pedido, required this.onTap});

  final PedidoResumen pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pedido ${pedido.numero}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const Spacer(),
                  ChipEstado(estado: pedido.estado),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.turquesa),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pedido.direccion ?? 'Sin dirección',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: AppColors.textoSecundario, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pedido.cliente)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pedido.cobrarAlEntregar ? const Color(0xFFFFF3E0) : AppColors.exitoClaro,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pedido.cobrarAlEntregar
                      ? 'Cobrar ${Formato.soles(pedido.total)} · ${pedido.tipoPago ?? ''}'
                      : 'Pagado en línea · no cobrar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: pedido.cobrarAlEntregar ? const Color(0xFFE65100) : AppColors.exito,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
