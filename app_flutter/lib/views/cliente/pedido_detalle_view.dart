import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/seguimiento.dart';
import '../../services/seguimiento_service.dart';
import '../../viewmodels/mis_pedidos_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/detalle_pedido_secciones.dart';
import '../widgets/estado_vacio.dart';
import 'pagar_pedido_view.dart';

/// Detalle y seguimiento de un pedido del cliente.
class PedidoDetalleView extends StatelessWidget {
  const PedidoDetalleView({super.key, this.paraPersonal = false});

  /// El administrador también lo usa (solo lectura), con los datos del cliente.
  final bool paraPersonal;

  static Route<void> ruta(int idPedido, {bool paraPersonal = false}) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => PedidoDetalleViewModel(context.read<SeguimientoService>(), idPedido),
      child: PedidoDetalleView(paraPersonal: paraPersonal),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PedidoDetalleViewModel>();
    final p = vm.pedido;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Detalle del pedido'),
      ),
      body: p == null
          ? (vm.error != null
                ? EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No pudimos cargar el pedido',
                    mensaje: vm.error,
                    accion: vm.cargar,
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CabeceraPedido(pedido: p),
                  if (_aviso(p) case final aviso?) ...[aviso, const SizedBox(height: 12)],
                  if (p.puedeReintentarPago && !paraPersonal) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          PagarPedidoView.ruta(idPedido: p.idPedido, numero: p.numero, total: p.total),
                        );
                        vm.cargar();
                      },
                      icon: const Icon(Icons.credit_card),
                      label: const Text('Reintentar pago'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SeccionesDetallePedido(pedido: p, paraPersonal: paraPersonal),
                ],
              ),
            ),
    );
  }

  /// Mensaje según el estado, para que el cliente sepa qué está pasando.
  Widget? _aviso(PedidoDetalle p) {
    if (p.estado.id == EstadoPedido.fallido) {
      return Aviso(
        titulo: 'Pedido cancelado',
        mensaje: p.motivoFallo ?? 'El pedido no pudo completarse.',
      );
    }
    if (p.puedeReintentarPago) {
      return const Aviso(
        titulo: 'Pago rechazado',
        mensaje: 'Tu pedido está registrado pero el pago no se aprobó. Paga con otra tarjeta para que lo preparemos.',
      );
    }
    final mensaje = switch (p.estado.id) {
      EstadoPedido.procesando => 'La botica está preparando tu pedido.',
      EstadoPedido.empaquetado => p.esDelivery
          ? 'Tu pedido está empaquetado y pronto saldrá a reparto.'
          : 'Tu pedido está empaquetado.',
      EstadoPedido.enCamino => 'Tu pedido está en camino.',
      EstadoPedido.listoRecoger => 'Tu pedido está listo. Acércate a la botica con tu DNI.',
      EstadoPedido.entregado => '¡Pedido entregado! Gracias por tu compra.',
      _ => null,
    };
    return mensaje == null ? null : Aviso(tipo: TipoAviso.info, mensaje: mensaje);
  }
}
