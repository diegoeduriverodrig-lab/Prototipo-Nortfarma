import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/producto.dart';
import '../../viewmodels/catalogo_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/producto_widgets.dart';
import 'producto_detalle_view.dart';

/// Búsqueda del catálogo con filtros por categoría, disponibilidad y orden.
class CatalogoView extends StatefulWidget {
  const CatalogoView({super.key});

  @override
  State<CatalogoView> createState() => _CatalogoViewState();
}

class _CatalogoViewState extends State<CatalogoView> {
  final _buscador = TextEditingController();
  int _versionVista = 0;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  /// Si la búsqueda llegó desde Inicio, se copia el texto al buscador.
  void _sincronizarBuscador(CatalogoViewModel vm) {
    if (vm.versionExterna == _versionVista) return;
    _versionVista = vm.versionExterna;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buscador.text = vm.termino;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    _sincronizarBuscador(vm);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Buscar productos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _buscador,
              textInputAction: TextInputAction.search,
              onChanged: vm.cambiarTermino,
              onSubmitted: (_) => vm.buscar(),
              decoration: InputDecoration(
                hintText: 'Nombre del producto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ListenableBuilder(
                  listenable: _buscador,
                  builder: (context, _) => _buscador.text.isEmpty
                      ? const SizedBox.shrink()
                      : ExcludeFocus(
                          child: IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _buscador.clear();
                              vm.cambiarTermino('');
                            },
                          ),
                        ),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FiltroCategorias(vm: vm),
          _BarraFiltros(vm: vm),
          if (!vm.coreDisponible)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Aviso(
                tipo: TipoAviso.info,
                mensaje:
                    'No pudimos consultar precios y stock en este momento. '
                    'Inténtalo de nuevo en unos minutos.',
              ),
            ),
          Expanded(child: _Resultados(vm: vm)),
        ],
      ),
    );
  }
}

class _FiltroCategorias extends StatelessWidget {
  const _FiltroCategorias({required this.vm});

  final CatalogoViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: vm.idCategoria == null,
              onSelected: (_) => vm.cambiarCategoria(null),
            ),
          ),
          for (final c in vm.categorias)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(iconoCategoria(c.iconoUrl), size: 18),
                label: Text(c.nombre),
                selected: vm.idCategoria == c.id,
                onSelected: (_) => vm.cambiarCategoria(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({required this.vm});

  final CatalogoViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              vm.cargando ? 'Buscando...' : '${vm.productos.length} resultados',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilterChip(
            label: const Text('Disponibles'),
            selected: vm.soloDisponibles,
            onSelected: vm.cambiarSoloDisponibles,
          ),
          PopupMenuButton<OrdenCatalogo>(
            tooltip: 'Ordenar',
            initialValue: vm.orden,
            onSelected: vm.cambiarOrden,
            itemBuilder: (_) => [
              for (final o in OrdenCatalogo.values)
                PopupMenuItem(value: o, child: Text(o.etiqueta)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 20, color: AppColors.turquesaOscuro),
                  const SizedBox(width: 4),
                  Text(
                    vm.orden.etiqueta,
                    style: const TextStyle(color: AppColors.turquesaOscuro, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resultados extends StatelessWidget {
  const _Resultados({required this.vm});

  final CatalogoViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.error != null && vm.productos.isEmpty) {
      return EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pudimos buscar',
        mensaje: vm.error,
        accion: vm.buscar,
      );
    }
    if (vm.cargando && vm.productos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.productos.isEmpty) {
      final hayFiltros = vm.termino.isNotEmpty || vm.idCategoria != null || vm.soloDisponibles;
      return EstadoVacio(
        icono: Icons.search_off,
        titulo: 'No encontramos productos',
        mensaje: hayFiltros
            ? 'Prueba con otro nombre o quita los filtros.'
            : 'Aún no hay productos en el catálogo.',
        accion: hayFiltros ? () => vm.aplicar() : null,
        textoAccion: 'Quitar filtros',
      );
    }

    return RefreshIndicator(
      onRefresh: vm.buscar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: vm.productos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = vm.productos[i];
          return FilaProducto(
            producto: p,
            onTap: () => Navigator.of(context).push(ProductoDetalleView.ruta(p)),
          );
        },
      ),
    );
  }
}
