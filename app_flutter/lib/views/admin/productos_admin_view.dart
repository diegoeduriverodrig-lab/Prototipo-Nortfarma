import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../models/admin.dart';
import '../../services/imagen_service.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import 'categorias_admin_view.dart';

/// Configuración del catálogo: nombre en la app, foto, categoría y venta en línea de cada producto.
/// Arriba aparecen los productos nuevos de Nortfarma, que aún no tienen categoría.
class ProductosAdminView extends StatelessWidget {
  const ProductosAdminView({super.key});

  Future<void> _editar(BuildContext context, ProductoAdmin p) async {
    final vm = context.read<ProductosAdminViewModel>();
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: _EditorProducto(producto: p)),
    );
    if (guardado == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductosAdminViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Catálogo de productos'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () async {
              await Navigator.of(context).push(CategoriasAdminView.ruta());
              vm.cargar(); // por si se renombró u ocultó alguna categoría
            },
            icon: const Icon(Icons.category_outlined),
            label: const Text('Categorías'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: vm.filtrar,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o código',
                prefixIcon: Icon(Icons.search),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: !vm.cargado
          ? const Center(child: CircularProgressIndicator())
          : vm.productos.isEmpty
          ? EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Sin productos',
              mensaje: vm.error,
              accion: vm.cargar,
            )
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: vm.productos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = vm.productos[i];
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _editar(context, p),
                      leading: _Miniatura(url: p.imagenUrl),
                      title: Text(p.nombre),
                      subtitle: Text(
                        '${p.nombreApp != null ? 'Nortfarma: ${p.nombreNortfarma}\n' : ''}'
                        '${p.idProductoCore} · ${p.categoria ?? 'NUEVO: sin categoría'}'
                        '${p.requiereReceta ? ' · receta' : ''}'
                        '${p.presentaciones.isEmpty ? '' : '\n${p.presentaciones.join(' · ')}'}',
                        style: p.esNuevo ? const TextStyle(color: Color(0xFFE65100)) : null,
                      ),
                      isThreeLine: p.presentaciones.isNotEmpty,
                      trailing: Icon(
                        p.aptoEcommerce ? Icons.storefront : Icons.visibility_off_outlined,
                        color: p.aptoEcommerce ? AppColors.exito : AppColors.textoSecundario,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final provisional = Container(
      width: 48,
      height: 48,
      color: AppColors.turquesaClaro,
      child: const Icon(Icons.medication_liquid_outlined, color: AppColors.turquesa),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null || url!.isEmpty
          ? provisional
          : Image.network(
              Config.urlImagen(url!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => provisional,
            ),
    );
  }
}

class _EditorProducto extends StatefulWidget {
  const _EditorProducto({required this.producto});

  final ProductoAdmin producto;

  @override
  State<_EditorProducto> createState() => _EditorProductoState();
}

class _EditorProductoState extends State<_EditorProducto> {
  final _formKey = GlobalKey<FormState>();
  late int? _idCategoria = widget.producto.idCategoria;
  late bool _apto = widget.producto.aptoEcommerce;
  late final _nombreApp = TextEditingController(text: widget.producto.nombreApp);
  late final _imagen = TextEditingController(text: widget.producto.imagenUrl);

  @override
  void dispose() {
    _nombreApp.dispose();
    _imagen.dispose();
    super.dispose();
  }

  Future<void> _subirFoto(OrigenImagen origen) async {
    final ruta = await context.read<ProductosAdminViewModel>().subirFoto(origen);
    if (ruta != null && mounted) setState(() => _imagen.text = ruta);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<ProductosAdminViewModel>().guardar(
      widget.producto,
      idCategoria: _idCategoria!,
      aptoEcommerce: _apto,
      imagenUrl: _imagen.text,
      nombreApp: _nombreApp.text,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductosAdminViewModel>();
    final imagen = _imagen.text.trim();
    final esFotoSubida = imagen.startsWith('productos/');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.producto.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(
                  'Código Nortfarma: ${widget.producto.idProductoCore}',
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 16),
                if (widget.producto.presentaciones.isNotEmpty)
                  Text(
                    'Se vende como: ${widget.producto.presentaciones.join(' · ')}',
                    style: const TextStyle(color: AppColors.textoSecundario),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreApp,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre en la app (opcional)',
                    helperText: 'En Nortfarma: ${widget.producto.nombreNortfarma}',
                    helperMaxLines: 3,
                  ),
                  validator: vm.validarNombreApp,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _idCategoria,
                  decoration: InputDecoration(
                    labelText: 'Categoría en la app',
                    helperText: widget.producto.esNuevo ? 'Producto nuevo: elige su categoría' : null,
                  ),
                  items: [
                    for (final c in vm.categorias)
                      DropdownMenuItem(value: c.id, child: Text(c.activa ? c.nombre : '${c.nombre} (oculta)')),
                  ],
                  onChanged: (id) => setState(() => _idCategoria = id ?? _idCategoria),
                  validator: (id) => id == null ? 'Elige una categoría' : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Venta en línea'),
                  subtitle: const Text('Si se apaga, el producto no aparece en el catálogo de la app.'),
                  value: _apto,
                  onChanged: (v) => setState(() => _apto = v),
                ),
                const SizedBox(height: 4),
                const Text('Foto principal', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: vm.subiendoFoto ? null : () => _subirFoto(OrigenImagen.camara),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: vm.subiendoFoto ? null : () => _subirFoto(OrigenImagen.galeria),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
                if (vm.subiendoFoto) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imagen,
                  keyboardType: TextInputType.url,
                  readOnly: esFotoSubida,
                  decoration: InputDecoration(
                    labelText: esFotoSubida ? 'Foto subida desde el celular' : 'O pega el enlace de una foto',
                    hintText: 'https://...',
                    suffixIcon: imagen.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Quitar foto',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_imagen.clear),
                          ),
                  ),
                  validator: vm.validarImagen,
                  onChanged: (_) => setState(() {}),
                ),
                if (imagen.startsWith('http') || esFotoSubida) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      Config.urlImagen(imagen),
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 60,
                        child: Center(child: Text('No se pudo cargar la imagen')),
                      ),
                    ),
                  ),
                ],
                if (vm.error != null) ...[const SizedBox(height: 12), Aviso(mensaje: vm.error!)],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: vm.cargando || vm.subiendoFoto ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
