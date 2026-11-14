import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../models/pedido.dart';
import '../../viewmodels/carrito_viewmodel.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import 'checkout_view.dart';

/// Carrito de compras (RNF07).
class CarritoView extends StatelessWidget {
  const CarritoView({super.key});

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de compras'),
        actions: [
          if (!carrito.vacio)
            TextButton(
              onPressed: () => _confirmarVaciar(context, carrito),
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: carrito.vacio
          ? EstadoVacio(
              icono: Icons.shopping_cart_outlined,
              titulo: 'Tu carrito está vacío',
              mensaje: 'Agrega productos desde el catálogo.',
              accion: () => context.read<NavegacionClienteViewModel>().ir(PestanaCliente.catalogo),
              textoAccion: 'Ver catálogo',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  carrito.items.length == 1 ? '1 producto' : '${carrito.items.length} productos',
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 8),
                for (final item in carrito.items) ...[
                  _FilaCarrito(item: item, carrito: carrito),
                  const SizedBox(height: 10),
                ],
                if (carrito.requiereReceta)
                  const Aviso(
                    tipo: TipoAviso.info,
                    titulo: 'Tu pedido incluye productos con receta',
                    mensaje: 'Te pediremos una foto de la receta médica al finalizar la compra.',
                  ),
                if (carrito.hayProblemasDeStock) ...[
                  const SizedBox(height: 10),
                  const Aviso(
                    mensaje: 'Algunos productos superan el stock disponible. Reduce la cantidad.',
                  ),
                ],
              ],
            ),
      bottomNavigationBar: carrito.vacio
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borde)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Subtotal', style: TextStyle(fontSize: 16)),
                        ),
                        Text(
                          Formato.soles(carrito.subtotal),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: carrito.hayProblemasDeStock
                          ? null
                          : () => Navigator.of(context).push(CheckoutView.ruta()),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Continuar compra'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmarVaciar(BuildContext context, CarritoViewModel carrito) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar el carrito?'),
        content: const Text('Se quitarán todos los productos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vaciar')),
        ],
      ),
    );
    if (ok == true) carrito.vaciar();
  }
}

class _FilaCarrito extends StatelessWidget {
  const _FilaCarrito({required this.item, required this.carrito});

  final ItemCarrito item;
  final CarritoViewModel carrito;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.sinStockSuficiente ? AppColors.rojo : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.turquesaClaro,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_liquid_outlined, color: AppColors.turquesa),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (item.nombrePresentacion.isNotEmpty)
                  Text(
                    item.nombrePresentacion,
                    style: const TextStyle(fontSize: 12, color: AppColors.turquesaOscuro, fontWeight: FontWeight.w600),
                  ),
                Text.rich(
                  TextSpan(
                    text: 'Precio c/u ${Formato.soles(item.precio)}',
                    children: [
                      if (item.conDescuento)
                        TextSpan(
                          text: '  ${Formato.soles(item.precioRegular)}',
                          style: const TextStyle(decoration: TextDecoration.lineThrough),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
                if (item.sinStockSuficiente)
                  Text(
                    item.stock <= 0 ? 'Agotado' : 'Solo quedan ${item.stock}',
                    style: const TextStyle(fontSize: 12, color: AppColors.rojo),
                  ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar uno',
                      onPressed: () => carrito.cambiarCantidad(item.clave, item.cantidad - 1),
                      icon: Icon(item.cantidad == 1 ? Icons.delete_outline : Icons.remove),
                    ),
                    Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Agregar uno',
                      onPressed: item.cantidad < item.stock
                          ? () => carrito.cambiarCantidad(item.clave, item.cantidad + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formato.soles(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => carrito.quitar(item.clave),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
