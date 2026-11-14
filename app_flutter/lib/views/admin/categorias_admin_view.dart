import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/admin.dart';
import '../../services/admin_service.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/producto_widgets.dart';

/// Gestión de categorías del catálogo: crear, editar, ocultar y eliminar.
/// Una categoría con productos no se elimina: se oculta o se pasan sus productos a otra.
class CategoriasAdminView extends StatelessWidget {
  const CategoriasAdminView({super.key});

  static Route<void> ruta() => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => CategoriasAdminViewModel(context.read<AdminService>()),
      child: const CategoriasAdminView(),
    ),
  );

  Future<void> _editar(BuildContext context, [CategoriaAdmin? categoria]) async {
    final vm = context.read<CategoriasAdminViewModel>();
    vm.limpiarError();
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: _EditorCategoria(categoria: categoria)),
    );
    if (guardado == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(categoria == null ? 'Categoría creada' : 'Categoría actualizada')),
      );
    }
  }

  Future<void> _eliminar(BuildContext context, CategoriaAdmin c) async {
    final vm = context.read<CategoriasAdminViewModel>();
    final mensajero = ScaffoldMessenger.of(context);
    if (c.productos > 0) {
      mensajero.showSnackBar(SnackBar(
        content: Text(
          '"${c.nombre}" tiene ${c.productos} producto${c.productos == 1 ? '' : 's'}. '
          'Pásalos a otra categoría u ocúltala.',
        ),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Se eliminará "${c.nombre}". No tiene productos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final eliminada = await vm.eliminar(c);
    mensajero.showSnackBar(SnackBar(content: Text(eliminada ? 'Categoría eliminada' : vm.error ?? 'No se pudo eliminar')));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriasAdminViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Categorías'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.cargado ? () => _editar(context) : null,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: !vm.cargado
          ? const Center(child: CircularProgressIndicator())
          : vm.categorias.isEmpty
          ? EstadoVacio(
              icono: Icons.category_outlined,
              titulo: 'Sin categorías',
              mensaje: vm.error,
              accion: vm.cargar,
            )
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  const Text(
                    'Las categorías ocultas no se muestran al cliente, ni sus productos. '
                    'Solo se puede eliminar una categoría sin productos.',
                    style: TextStyle(color: AppColors.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  if (vm.error != null) ...[Aviso(mensaje: vm.error!), const SizedBox(height: 12)],
                  for (final c in vm.categorias)
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _editar(context, c),
                        leading: CircleAvatar(
                          backgroundColor: c.activa ? AppColors.turquesaClaro : const Color(0xFFEEEEEE),
                          child: Icon(
                            iconoCategoria(c.icono),
                            color: c.activa ? AppColors.turquesa : AppColors.textoSecundario,
                          ),
                        ),
                        title: Text(c.nombre),
                        subtitle: Text(
                          '${c.productos} producto${c.productos == 1 ? '' : 's'}${c.activa ? '' : ' · OCULTA'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: c.activa,
                              onChanged: vm.cargando ? null : (v) => vm.cambiarVisible(c, v),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: vm.cargando ? null : () => _eliminar(context, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Crear o editar una categoría: nombre, ícono y si se muestra al cliente.
class _EditorCategoria extends StatefulWidget {
  const _EditorCategoria({this.categoria});

  final CategoriaAdmin? categoria;

  @override
  State<_EditorCategoria> createState() => _EditorCategoriaState();
}

class _EditorCategoriaState extends State<_EditorCategoria> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.categoria?.nombre);
  late String? _icono = widget.categoria?.icono;
  late bool _activa = widget.categoria?.activa ?? true;
  bool _sinIcono = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valido = _formKey.currentState!.validate();
    setState(() => _sinIcono = _icono == null);
    if (!valido || _icono == null) return;
    final ok = await context.read<CategoriasAdminViewModel>().guardar(
      idCategoria: widget.categoria?.id,
      nombre: _nombre.text,
      icono: _icono!,
      activa: _activa,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoriasAdminViewModel>();
    final editando = widget.categoria != null;

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
                Text(
                  editando ? 'Editar categoría' : 'Nueva categoría',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => vm.validarNombre(v, idActual: widget.categoria?.id),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ícono',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _sinIcono ? AppColors.rojo : null),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final clave in vm.iconos)
                      ChoiceChip(
                        showCheckmark: false,
                        selected: _icono == clave,
                        selectedColor: AppColors.turquesaClaro,
                        label: Icon(iconoCategoria(clave), color: AppColors.turquesa),
                        onSelected: (_) => setState(() {
                          _icono = clave;
                          _sinIcono = false;
                        }),
                      ),
                  ],
                ),
                if (_sinIcono)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Elige un ícono', style: TextStyle(color: AppColors.rojo, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible para el cliente'),
                  subtitle: const Text('Si se apaga, la categoría y sus productos no aparecen en la app.'),
                  value: _activa,
                  onChanged: (v) => setState(() => _activa = v),
                ),
                if (vm.error != null) ...[const SizedBox(height: 8), Aviso(mensaje: vm.error!)],
                const SizedBox(height: 16),
                FilledButton(onPressed: vm.cargando ? null : _guardar, child: const Text('Guardar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
