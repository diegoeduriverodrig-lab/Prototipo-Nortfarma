import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../models/producto.dart';
import '../../services/catalogo_service.dart';
import '../../viewmodels/carrito_viewmodel.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import '../../viewmodels/producto_detalle_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/producto_widgets.dart';

/// Detalle del producto: el cliente elige la presentación (caja, blíster o unidad);
/// precio, descuento y stock se consultan en tiempo real.
class ProductoDetalleView extends StatelessWidget {
  const ProductoDetalleView({super.key});

  static Route<void> ruta(Producto producto) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => ProductoDetalleViewModel(
        context.read<CatalogoService>(),
        producto.idProducto,
        inicial: producto,
      ),
      child: const ProductoDetalleView(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductoDetalleViewModel>();
    final producto = vm.producto;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Detalle del producto'),
      ),
      body: producto == null
          ? (vm.error != null
                ? EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No pudimos cargar el producto',
                    mensaje: vm.error,
                    accion: vm.cargar,
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: ImagenProducto(producto: producto, tamanoIcono: 72),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.categoria.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.turquesaOscuro,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          producto.nombre,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          producto.especificaciones,
                          style: const TextStyle(color: AppColors.textoSecundario, height: 1.4),
                        ),
                        if (producto.presentaciones.length > 1) ...[
                          const SizedBox(height: 20),
                          const Text('¿Cómo lo quieres?', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _SelectorPresentacion(vm: vm),
                        ],
                        const SizedBox(height: 20),
                        _PrecioYStock(vm: vm),
                        if (vm.cargando) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                        if (producto.requiereReceta) ...[
                          const SizedBox(height: 20),
                          const Aviso(
                            tipo: TipoAviso.info,
                            titulo: 'Requiere receta médica',
                            mensaje: 'Al finalizar la compra te pediremos una foto de tu receta médica.',
                          ),
                        ],
                        if (vm.error != null) ...[
                          const SizedBox(height: 16),
                          Aviso(mensaje: vm.error!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: producto == null ? null : _BarraCompra(vm: vm),
    );
  }
}

/// Botones para elegir caja, blíster o unidad, con el precio de cada uno.
class _SelectorPresentacion extends StatelessWidget {
  const _SelectorPresentacion({required this.vm});

  final ProductoDetalleViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in vm.producto!.presentaciones)
          ChoiceChip(
            selected: p.tipo == vm.tipo,
            onSelected: (_) => vm.elegirPresentacion(p.tipo),
            showCheckmark: false,
            selectedColor: AppColors.turquesaClaro,
            side: BorderSide(color: p.tipo == vm.tipo ? AppColors.turquesa : AppColors.borde),
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  p.disponible ? Formato.soles(p.precio) : 'Agotado',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.disponible ? AppColors.textoSecundario : AppColors.rojo,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Precio de la presentación elegida (con descuento si hay) y su stock.
class _PrecioYStock extends StatelessWidget {
  const _PrecioYStock({required this.vm});

  final ProductoDetalleViewModel vm;

  @override
  Widget build(BuildContext context) {
    final producto = vm.producto!;
    final p = vm.presentacion;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    p == null ? 'Precio' : 'Precio · ${p.nombre}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                  if (producto.conDescuento) ...[
                    const SizedBox(width: 6),
                    EtiquetaDescuento(porcentaje: producto.descuento),
                  ],
                ],
              ),
              PrecioProducto(precio: p?.precio, precioRegular: p?.precioRegular, tamano: 28),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (p == null)
              EtiquetaStock(producto: producto)
            else ...[
              _EstadoStock(disponible: p.disponible, pocas: p.stock <= Producto.umbralPocasUnidades),
              if (p.disponible)
                Text(
                  '${p.stock} disponibles',
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EstadoStock extends StatelessWidget {
  const _EstadoStock({required this.disponible, required this.pocas});

  final bool disponible;
  final bool pocas;

  @override
  Widget build(BuildContext context) {
    final (String texto, Color color) = !disponible
        ? ('Agotado', const Color(0xFFC62828))
        : pocas
        ? ('Pocas unidades', const Color(0xFFE65100))
        : ('En stock', AppColors.exito);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BarraCompra extends StatelessWidget {
  const _BarraCompra({required this.vm});

  final ProductoDetalleViewModel vm;

  void _agregar(BuildContext context) {
    final resultado = context.read<CarritoViewModel>().agregar(vm.producto!, vm.cantidad, vm.tipo);
    final mensaje = switch (resultado) {
      ResultadoAgregar.agregado => 'Producto añadido al carrito',
      ResultadoAgregar.superaStock => 'Añadimos solo las unidades disponibles',
      ResultadoAgregar.sinStock => 'Este producto está agotado',
    };
    // Se guardan antes: el aviso puede seguir visible después de cerrar esta pantalla.
    final mensajero = ScaffoldMessenger.of(context);
    final navegacion = context.read<NavegacionClienteViewModel>();
    final navegador = Navigator.of(context);
    mensajero.hideCurrentSnackBar();
    mensajero.showSnackBar(
      SnackBar(
        content: Text(mensaje),
        action: resultado == ResultadoAgregar.sinStock
            ? null
            : SnackBarAction(
                label: 'Ver carrito',
                onPressed: () {
                  navegacion.ir(PestanaCliente.carrito);
                  navegador.popUntil((ruta) => ruta.isFirst);
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borde),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: vm.puedeComprar && vm.puedeRestar ? vm.restar : null,
                    icon: const Icon(Icons.remove),
                    tooltip: 'Quitar uno',
                  ),
                  Text('${vm.cantidad}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: vm.puedeComprar && vm.puedeSumar ? vm.sumar : null,
                    icon: const Icon(Icons.add),
                    tooltip: 'Agregar uno',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: vm.puedeComprar ? () => _agregar(context) : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  vm.puedeComprar ? 'Añadir  ${Formato.soles(vm.subtotal)}' : 'Agotado',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
