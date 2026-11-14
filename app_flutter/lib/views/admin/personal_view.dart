import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/admin.dart';
import '../../models/usuario.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';

/// Gestión del personal (RF17): ver, crear, editar y quitar acceso.
class PersonalView extends StatelessWidget {
  const PersonalView({super.key});

  static const _titulos = {
    Rol.encargado: 'Encargados de botica',
    Rol.repartidor: 'Repartidores',
    Rol.administrador: 'Administradores',
  };

  Future<void> _abrirFormulario(BuildContext context, {MiembroPersonal? miembro}) async {
    final vm = context.read<PersonalViewModel>();
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: vm, child: _FormularioPersonal(miembro: miembro)),
      ),
    );
    if (guardado == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(miembro == null ? 'Cuenta creada' : 'Cambios guardados')),
      );
    }
  }

  Future<void> _quitarAcceso(BuildContext context, MiembroPersonal m) async {
    final vm = context.read<PersonalViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar acceso'),
        content: Text(
          '${m.nombreCompleto} dejará de ver los módulos de ${m.rol.nombre}. '
          'Su cuenta seguirá existiendo como cliente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final hecho = await vm.quitarAcceso(m);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hecho ? 'Acceso quitado' : vm.error ?? 'No se pudo quitar el acceso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PersonalViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Gestión de personal'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo'),
      ),
      body: !vm.cargado
          ? const Center(child: CircularProgressIndicator())
          : vm.personal.isEmpty
          ? EstadoVacio(
              icono: Icons.badge_outlined,
              titulo: 'Sin personal registrado',
              mensaje: vm.error,
              accion: vm.cargar,
            )
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (vm.error != null) ...[Aviso(mensaje: vm.error!), const SizedBox(height: 12)],
                  for (final rol in [Rol.encargado, Rol.repartidor, Rol.administrador]) ...[
                    if (vm.personal.any((m) => m.rol == rol))
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          _titulos[rol]!,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textoSecundario),
                        ),
                      ),
                    for (final m in vm.personal.where((m) => m.rol == rol))
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.turquesaClaro,
                            child: Text(m.nombre[0], style: const TextStyle(color: AppColors.turquesaOscuro)),
                          ),
                          title: Text(m.nombreCompleto),
                          subtitle: Text([m.correo, if (m.botica != null) m.botica!].join('\n')),
                          isThreeLine: m.botica != null,
                          onTap: () => _abrirFormulario(context, miembro: m),
                          trailing: PopupMenuButton<String>(
                            onSelected: (accion) => accion == 'editar'
                                ? _abrirFormulario(context, miembro: m)
                                : _quitarAcceso(context, m),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'editar', child: Text('Editar')),
                              PopupMenuItem(value: 'quitar', child: Text('Quitar acceso')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Crear o editar una cuenta del personal.
class _FormularioPersonal extends StatefulWidget {
  const _FormularioPersonal({this.miembro});

  final MiembroPersonal? miembro;

  @override
  State<_FormularioPersonal> createState() => _FormularioPersonalState();
}

class _FormularioPersonalState extends State<_FormularioPersonal> {
  final _formKey = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.miembro?.nombre);
  late final _apellidos = TextEditingController(text: widget.miembro?.apellido);
  late final _celular = TextEditingController(text: widget.miembro?.telefono);
  final _dni = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  late Rol _rol = widget.miembro?.rol ?? Rol.repartidor;
  late int? _idBotica = widget.miembro?.idBotica;

  bool get _editando => widget.miembro != null;

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _celular, _dni, _correo, _contrasena]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<PersonalViewModel>();
    final ok = await vm.guardar(
      DatosPersonal(
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        celular: _celular.text,
        rol: _rol,
        idBotica: _rol == Rol.encargado ? _idBotica : null,
        dni: _editando ? null : _dni.text,
        correo: _editando ? null : _correo.text,
        contrasena: _editando ? null : _contrasena.text,
      ),
      existente: widget.miembro,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PersonalViewModel>();

    Widget campo(
      TextEditingController c,
      String etiqueta,
      FormFieldValidator<String> validador, {
      TextInputType? teclado,
      List<TextInputFormatter>? formato,
      bool oculto = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: teclado,
        inputFormatters: formato,
        obscureText: oculto,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: etiqueta),
        validator: validador,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: Text(_editando ? 'Editar cuenta' : 'Nueva cuenta de personal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<Rol>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                for (final r in [Rol.encargado, Rol.repartidor, Rol.administrador])
                  DropdownMenuItem(value: r, child: Text(r.nombre)),
              ],
              onChanged: (r) => setState(() => _rol = r ?? _rol),
            ),
            const SizedBox(height: 14),
            if (_rol == Rol.encargado) ...[
              DropdownButtonFormField<int>(
                initialValue: _idBotica,
                decoration: const InputDecoration(labelText: 'Botica'),
                items: [for (final b in vm.boticas) DropdownMenuItem(value: b.id, child: Text(b.nombre))],
                onChanged: (id) => setState(() => _idBotica = id),
                validator: (id) => vm.validarBotica(_rol, id),
              ),
              const SizedBox(height: 14),
            ],
            campo(_nombres, 'Nombres', vm.validarNombres),
            campo(_apellidos, 'Apellidos', vm.validarApellidos),
            campo(
              _celular,
              'Celular',
              vm.validarCelular,
              teclado: TextInputType.phone,
              formato: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            ),
            if (_editando)
              Aviso(
                tipo: TipoAviso.info,
                mensaje: '${widget.miembro!.correo} · DNI ${widget.miembro!.dni}. '
                    'El correo y el DNI no se pueden cambiar.',
              )
            else ...[
              campo(
                _dni,
                'DNI',
                vm.validarDni,
                teclado: TextInputType.number,
                formato: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              ),
              campo(_correo, 'Correo electrónico', vm.validarCorreo, teclado: TextInputType.emailAddress),
              campo(_contrasena, 'Contraseña inicial', vm.validarContrasena, oculto: true),
              const Text(
                'Comparte la contraseña inicial con la persona; podrá cambiarla con "¿Olvidaste tu contraseña?".',
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              ),
            ],
            if (vm.error != null) ...[const SizedBox(height: 12), Aviso(mensaje: vm.error!)],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: vm.cargando ? null : _guardar,
              child: vm.cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editando ? 'Guardar cambios' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
