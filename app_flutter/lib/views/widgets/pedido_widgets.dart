import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../models/seguimiento.dart';

/// Color de cada estado del pedido.
Color colorEstado(int idEstado) => switch (idEstado) {
  EstadoPedido.procesando => const Color(0xFFE65100),
  EstadoPedido.empaquetado => const Color(0xFF1565C0),
  EstadoPedido.enCamino => const Color(0xFF6A1B9A),
  EstadoPedido.listoRecoger => AppColors.turquesaOscuro,
  EstadoPedido.entregado => AppColors.exito,
  EstadoPedido.fallido => const Color(0xFFC62828),
  _ => AppColors.textoSecundario,
};

IconData iconoEstado(int idEstado) => switch (idEstado) {
  EstadoPedido.procesando => Icons.hourglass_top,
  EstadoPedido.empaquetado => Icons.inventory_2_outlined,
  EstadoPedido.enCamino => Icons.delivery_dining_outlined,
  EstadoPedido.listoRecoger => Icons.storefront_outlined,
  EstadoPedido.entregado => Icons.check_circle_outline,
  EstadoPedido.fallido => Icons.cancel_outlined,
  _ => Icons.circle_outlined,
};

/// Etiqueta de color con el nombre del estado.
class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.estado});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final color = colorEstado(estado.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstado(estado.id), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            estado.nombre,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de resumen de un pedido (lista del cliente y bandeja del encargado).
class TarjetaPedido extends StatelessWidget {
  const TarjetaPedido({
    super.key,
    required this.pedido,
    required this.onTap,
    this.mostrarCliente = false,
    this.resaltar = false,
  });

  final PedidoResumen pedido;
  final VoidCallback onTap;
  final bool mostrarCliente;

  /// Para destacar pedidos nuevos en la bandeja.
  final bool resaltar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colorEstado(pedido.estado.id), width: resaltar ? 6 : 4),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pedido ${pedido.numero}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  if (resaltar) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.rojo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NUEVO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const Spacer(),
                  ChipEstado(estado: pedido.estado),
                ],
              ),
              const SizedBox(height: 6),
              if (mostrarCliente)
                Text(pedido.cliente, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${Formato.fechaHora(pedido.fecha)} · ${pedido.productos} prod. · '
                '${pedido.esDelivery ? 'Delivery' : 'Recojo en botica'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (pedido.tieneReceta) const _Etiqueta('Con receta'),
                  if (pedido.estadoPago != null)
                    _Etiqueta(pedido.estadoPago == 'Aprobado' ? 'Pagado' : 'Pago: ${pedido.estadoPago}'),
                  const Spacer(),
                  Text(
                    Formato.soles(pedido.total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.fondo, borderRadius: BorderRadius.circular(6)),
      child: Text(texto, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    );
  }
}

/// Historial de estados del pedido en forma de línea de tiempo.
class LineaTiempo extends StatelessWidget {
  const LineaTiempo({super.key, required this.historial, this.mostrarResponsable = false});

  final List<CambioEstado> historial;
  final bool mostrarResponsable;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < historial.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Icon(
                        iconoEstado(historial[i].estado.id),
                        size: 20,
                        color: colorEstado(historial[i].estado.id),
                      ),
                      if (i < historial.length - 1)
                        Expanded(child: Container(width: 2, color: AppColors.borde)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          historial[i].estado.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (historial[i].motivo != null) Text(historial[i].motivo!),
                        Text(
                          [
                            Formato.fechaHora(historial[i].fecha),
                            if (mostrarResponsable && historial[i].responsable != null)
                              historial[i].responsable!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Sección con título dentro de una tarjeta blanca.
class SeccionTarjeta extends StatelessWidget {
  const SeccionTarjeta({super.key, required this.titulo, required this.child, this.icono});

  final String titulo;
  final Widget child;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 20, color: AppColors.turquesa),
                const SizedBox(width: 8),
              ],
              Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Fila "etiqueta ...... valor".
class FilaDato extends StatelessWidget {
  const FilaDato({super.key, required this.etiqueta, required this.valor, this.resaltado = false});

  final String etiqueta;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: resaltado ? 17 : 14,
      fontWeight: resaltado ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario)),
          ),
          Expanded(child: Text(valor, textAlign: TextAlign.right, style: estilo)),
        ],
      ),
    );
  }
}
