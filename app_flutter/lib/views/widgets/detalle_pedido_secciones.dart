import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../models/seguimiento.dart';
import 'pedido_widgets.dart';
import 'ver_receta_view.dart';

/// Secciones del detalle de un pedido, comunes al cliente y al personal.
class SeccionesDetallePedido extends StatelessWidget {
  const SeccionesDetallePedido({super.key, required this.pedido, this.paraPersonal = false});

  final PedidoDetalle pedido;

  /// El personal ve datos del cliente y quién hizo cada cambio.
  final bool paraPersonal;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeccionTarjeta(
          titulo: 'Productos',
          icono: Icons.medication_outlined,
          child: Column(
            children: [
              for (final i in p.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: '${i.cantidad} x ${i.nombre}',
                            children: [
                              if (i.presentacion.isNotEmpty)
                                TextSpan(
                                  text: '\n${i.presentacion} · ${Formato.soles(i.precioUnitario)} c/u'
                                      '${i.descuento > 0 ? ' (-${i.descuento.toStringAsFixed(0)}%)' : ''}',
                                  style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                                ),
                              if (i.requiereReceta)
                                const TextSpan(
                                  text: '  (receta)',
                                  style: TextStyle(color: Color(0xFFE65100), fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Text(Formato.soles(i.total)),
                    ],
                  ),
                ),
              const Divider(height: 18),
              FilaDato(etiqueta: 'Subtotal', valor: Formato.soles(p.subtotal)),
              FilaDato(etiqueta: 'Envío', valor: Formato.soles(p.costoEnvio)),
              FilaDato(etiqueta: 'Total', valor: Formato.soles(p.total), resaltado: true),
            ],
          ),
        ),
        if (paraPersonal && p.cliente != null)
          SeccionTarjeta(
            titulo: 'Cliente',
            icono: Icons.person_outline,
            child: Column(
              children: [
                FilaDato(etiqueta: 'Nombre', valor: p.cliente!.nombre),
                FilaDato(etiqueta: 'DNI', valor: p.cliente!.dni ?? '-'),
                FilaDato(etiqueta: 'Celular', valor: p.cliente!.telefono ?? '-'),
              ],
            ),
          ),
        SeccionTarjeta(
          titulo: p.esDelivery ? 'Delivery' : 'Recojo en botica',
          icono: p.esDelivery ? Icons.delivery_dining_outlined : Icons.storefront_outlined,
          child: Column(
            children: [
              if (p.direccion != null) FilaDato(etiqueta: 'Dirección', valor: p.direccion!),
              if (p.boticaNombre != null)
                FilaDato(etiqueta: p.esDelivery ? 'Despacha' : 'Botica', valor: p.boticaNombre!),
              if (!p.esDelivery && p.boticaDireccion != null)
                FilaDato(etiqueta: 'Dirección', valor: p.boticaDireccion!),
              if (p.repartidor != null)
                FilaDato(
                  etiqueta: 'Repartidor',
                  valor: [p.repartidor!.nombre, if (p.repartidor!.telefono != null) p.repartidor!.telefono!]
                      .join(' · '),
                ),
            ],
          ),
        ),
        SeccionTarjeta(
          titulo: 'Pago y comprobante',
          icono: Icons.receipt_outlined,
          child: Column(
            children: [
              FilaDato(etiqueta: 'Método', valor: p.tipoPago),
              FilaDato(
                etiqueta: 'Estado',
                valor: switch (p.estadoPago) {
                  'Aprobado' => 'Pagado',
                  'Pendiente' when p.estado.id == EstadoPedido.fallido => 'Sin cobro (pedido cancelado)',
                  'Pendiente' => 'Por pagar al recibir',
                  final otro => otro ?? '-',
                },
              ),
              FilaDato(
                etiqueta: 'Comprobante',
                valor: p.numeroComprobante == null ? p.comprobante : '${p.comprobante} ${p.numeroComprobante}',
              ),
              if (p.ruc != null) FilaDato(etiqueta: 'RUC', valor: '${p.ruc} · ${p.razonSocial ?? ''}'),
            ],
          ),
        ),
        if (p.recetaRuta != null)
          SeccionTarjeta(
            titulo: 'Receta médica',
            icono: Icons.receipt_long_outlined,
            child: Row(
              children: [
                const Expanded(child: Text('Foto adjuntada por el cliente')),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    VerRecetaView.ruta(rutaReceta: p.recetaRuta!, numeroPedido: p.numero),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Ver foto'),
                ),
              ],
            ),
          ),
        if (p.entrega != null) SeccionEntrega(entrega: p.entrega!, numeroPedido: p.numero),
        SeccionTarjeta(
          titulo: 'Seguimiento',
          icono: Icons.timeline,
          child: p.historial.isEmpty
              ? const Text('Sin movimientos', style: TextStyle(color: AppColors.textoSecundario))
              : LineaTiempo(historial: p.historial, mostrarResponsable: paraPersonal),
        ),
      ],
    );
  }
}

/// Entrega a domicilio: horas de asignación, salida y entrega, evidencia e incidencias.
class SeccionEntrega extends StatelessWidget {
  const SeccionEntrega({super.key, required this.entrega, required this.numeroPedido});

  final InfoEntrega entrega;
  final String numeroPedido;

  Future<void> _abrirUbicacion(BuildContext context) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${entrega.latitud},${entrega.longitud}');
    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = entrega;
    String hora(DateTime? f) => f == null ? 'Pendiente' : Formato.fechaHora(f);
    return SeccionTarjeta(
      titulo: 'Entrega a domicilio',
      icono: Icons.delivery_dining_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilaDato(etiqueta: 'Asignado', valor: hora(e.fechaAsignacion)),
          FilaDato(etiqueta: 'Salida', valor: hora(e.fechaSalida)),
          FilaDato(etiqueta: 'Entregado', valor: hora(e.fechaEntrega)),
          if (e.observacion != null) FilaDato(etiqueta: 'Observación', valor: e.observacion!),
          if (e.evidencia != null || e.latitud != null)
            Wrap(
              spacing: 4,
              children: [
                if (e.evidencia != null)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      VerImagenView.ruta(
                        titulo: 'Entrega · Pedido $numeroPedido',
                        url: Config.urlImagen(e.evidencia!),
                      ),
                    ),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Foto de la entrega'),
                  ),
                if (e.latitud != null && e.longitud != null)
                  TextButton.icon(
                    onPressed: () => _abrirUbicacion(context),
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Dónde se entregó'),
                  ),
              ],
            ),
          if (e.incidencias.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Incidencias', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final i in e.incidencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i.terminaEntrega ? Icons.cancel_outlined : Icons.report_problem_outlined,
                      size: 18,
                      color: i.terminaEntrega ? const Color(0xFFC62828) : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${i.tipo}${i.detalle == null ? '' : ': ${i.detalle}'}\n${Formato.fechaHora(i.fecha)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Cabecera del detalle: número, fecha y estado.
class CabeceraPedido extends StatelessWidget {
  const CabeceraPedido({super.key, required this.pedido});

  final PedidoDetalle pedido;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido ${pedido.numero}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  Formato.fechaHora(pedido.fecha),
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          ChipEstado(estado: pedido.estado),
        ],
      ),
    );
  }
}
