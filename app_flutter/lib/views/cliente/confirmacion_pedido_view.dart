import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../models/pedido.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import '../widgets/aviso.dart';
import 'pagar_pedido_view.dart';

/// Confirmación del pedido con su número y estado. Si la tarjeta fue rechazada,
/// el pedido queda registrado y se ofrece pagar con otra tarjeta.
class ConfirmacionPedidoView extends StatefulWidget {
  const ConfirmacionPedidoView({super.key, required this.pedido});

  final PedidoRegistrado pedido;

  static Route<void> ruta(PedidoRegistrado pedido) =>
      MaterialPageRoute(builder: (_) => ConfirmacionPedidoView(pedido: pedido));

  @override
  State<ConfirmacionPedidoView> createState() => _ConfirmacionPedidoViewState();
}

class _ConfirmacionPedidoViewState extends State<ConfirmacionPedidoView> {
  late bool _rechazado = widget.pedido.pagoRechazado;

  void _volver(BuildContext context, PestanaCliente pestana) {
    context.read<NavegacionClienteViewModel>().ir(pestana);
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  Future<void> _pagarDeNuevo() async {
    final p = widget.pedido;
    final pagado = await Navigator.of(context).push(
      PagarPedidoView.ruta(idPedido: p.idPedido, numero: p.numero, total: p.total, motivoRechazo: p.mensajePago),
    );
    if (pagado == true && mounted) setState(() => _rechazado = false);
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final pagado = pedido.estadoPago == 'Pagado' || (pedido.pagoRechazado && !_rechazado);
    final esDelivery = pedido.tipoEntrega == 'Delivery';

    return PopScope(
      // Volver atrás no regresa al checkout (el carrito ya se vació).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volver(context, PestanaCliente.inicio);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: _rechazado ? const Color(0xFFFFF3E0) : AppColors.exitoClaro,
                  child: Icon(
                    _rechazado ? Icons.credit_card_off_outlined : Icons.check_circle,
                    size: 56,
                    color: _rechazado ? const Color(0xFFE65100) : AppColors.exito,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _rechazado ? 'Pedido registrado, falta el pago' : '¡Pedido registrado!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Pedido ${pedido.numero}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.turquesaOscuro),
              ),
              const SizedBox(height: 24),
              if (_rechazado) ...[
                Aviso(
                  titulo: 'Tu tarjeta fue rechazada',
                  mensaje: '${pedido.mensajePago ?? 'El pago no se aprobó.'} '
                      'Tu pedido se preparará cuando el pago sea aprobado.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pagarDeNuevo,
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Pagar con otra tarjeta'),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _Dato(etiqueta: 'Estado', valor: pedido.estadoPedido),
                    if (pedido.comprobante != null) _Dato(etiqueta: 'Comprobante', valor: pedido.comprobante!),
                    _Dato(
                      etiqueta: 'Pago',
                      valor: pagado ? 'Pagado' : (_rechazado ? 'Rechazado' : 'Por pagar al recibir'),
                    ),
                    _Dato(etiqueta: 'Entrega', valor: esDelivery ? 'Delivery' : 'Recojo en botica'),
                    _Dato(etiqueta: esDelivery ? 'Despacha' : 'Recoge en', valor: pedido.botica.nombre),
                    if (!esDelivery) _Dato(etiqueta: 'Dirección', valor: pedido.botica.direccion),
                    const Divider(height: 24),
                    _Dato(etiqueta: 'Subtotal', valor: Formato.soles(pedido.subtotal)),
                    _Dato(etiqueta: 'Envío', valor: Formato.soles(pedido.costoEnvio)),
                    _Dato(etiqueta: 'Total', valor: Formato.soles(pedido.total), resaltado: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                esDelivery
                    ? 'Te avisaremos cuando tu pedido esté en camino.'
                    : 'Te avisaremos cuando tu pedido esté listo para recoger.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSecundario),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _volver(context, PestanaCliente.pedidos),
                child: const Text('Ver mis pedidos'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _volver(context, PestanaCliente.inicio),
                child: const Text('Seguir comprando'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.resaltado = false});

  final String etiqueta;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: resaltado ? 18 : 14,
      fontWeight: resaltado ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario)),
          ),
          Expanded(child: Text(valor, textAlign: TextAlign.right, style: estilo)),
        ],
      ),
    );
  }
}
