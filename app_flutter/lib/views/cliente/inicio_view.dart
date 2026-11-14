import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/producto.dart';
import '../../viewmodels/carrito_viewmodel.dart';
import '../../viewmodels/inicio_viewmodel.dart';
import '../../viewmodels/navegacion_cliente_viewmodel.dart';
import '../../viewmodels/sesion_viewmodel.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/producto_widgets.dart';
import 'producto_detalle_view.dart';

typedef AbrirCatalogo = void Function({String termino, int? idCategoria});

/// Inicio del cliente: buscador, categorías y productos disponibles.
class InicioView extends StatelessWidget {
  const InicioView({super.key, required this.onAbrirCatalogo});

  final AbrirCatalogo onAbrirCatalogo;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    final usuario = context.watch<SesionViewModel>().usuario;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: vm.cargar,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Cabecera(
                nombre: usuario?.primerNombre ?? '',
                onBuscar: (termino) => onAbrirCatalogo(termino: termino),
              ),
            ),
            const SliverToBoxAdapter(child: _Banner()),
            SliverToBoxAdapter(
              child: _TituloSeccion(
                titulo: 'Compra por categoría',
                accion: 'Ver todas',
                onAccion: () => onAbrirCatalogo(),
              ),
            ),
            if (vm.error != null && vm.categorias.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EstadoVacio(
                  icono: Icons.cloud_off_outlined,
                  titulo: 'No pudimos cargar el catálogo',
                  mensaje: vm.error,
                  accion: vm.cargar,
                ),
              )
            else if (vm.cargando && vm.categorias.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vm.categorias.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final c = vm.categorias[i];
                      return _BotonCategoria(
                        nombre: c.nombre,
                        icono: iconoCategoria(c.iconoUrl),
                        onTap: () => onAbrirCatalogo(idCategoria: c.id),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _TituloSeccion(
                  titulo: vm.sonOfertas ? 'Ofertas' : 'Productos disponibles',
                  accion: 'Catálogo',
                  onAccion: () => onAbrirCatalogo(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.52,
                  ),
                  itemCount: vm.destacados.length,
                  itemBuilder: (context, i) {
                    final p = vm.destacados[i];
                    return TarjetaProducto(
                      producto: p,
                      onTap: () => Navigator.of(context).push(ProductoDetalleView.ruta(p)),
                      onComprar: () => _comprar(context, p),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Comprar" desde la tarjeta: añade 1 de la primera presentación con stock y abre el carrito.
void _comprar(BuildContext context, Producto producto) {
  final presentacion = producto.presentaciones.where((p) => p.disponible).firstOrNull;
  final mensajero = ScaffoldMessenger.of(context);
  mensajero.hideCurrentSnackBar();
  if (presentacion == null) {
    mensajero.showSnackBar(const SnackBar(content: Text('Este producto está agotado')));
    return;
  }
  context.read<CarritoViewModel>().agregar(producto, 1, presentacion.tipo);
  context.read<NavegacionClienteViewModel>().ir(PestanaCliente.carrito);
  mensajero.showSnackBar(SnackBar(content: Text('${producto.nombre} añadido al carrito')));
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.nombre, required this.onBuscar});

  final String nombre;
  final ValueChanged<String> onBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.turquesa,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset('assets/images/logo_boticas_felicidad.png', height: 36),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const Text(
                          'Pedidos en línea',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Busca medicamentos y bienestar',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (texto) {
                  if (texto.trim().isNotEmpty) onBuscar(texto.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.turquesaClaro, Color(0xFFD4EFEF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.rojo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SEMANA SALUDABLE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hasta 25% menos en bienestar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Compra hoy · delivery rápido',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_pharmacy_outlined, size: 56, color: AppColors.turquesa),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo, required this.accion, required this.onAccion});

  final String titulo;
  final String accion;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          TextButton(onPressed: onAccion, child: Text(accion)),
        ],
      ),
    );
  }
}

class _BotonCategoria extends StatelessWidget {
  const _BotonCategoria({required this.nombre, required this.icono, required this.onTap});

  final String nombre;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borde),
              ),
              child: Icon(icono, color: AppColors.turquesa),
            ),
            const SizedBox(height: 6),
            Text(
              nombre,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
