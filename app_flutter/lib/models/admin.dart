/// Modelos del panel del Administrador.
library;

import 'usuario.dart';

class Conteo {
  const Conteo({required this.id, required this.nombre, required this.cantidad});

  factory Conteo.desdeJson(Map<String, dynamic> json) => Conteo(
    id: json['id'].toString(),
    nombre: json['nombre'] as String,
    cantidad: json['cantidad'] as int,
  );

  final String id;
  final String nombre;
  final int cantidad;
}

class ResumenAdmin {
  const ResumenAdmin({
    required this.pedidosPorEstado,
    required this.pedidosHoy,
    required this.ventasHoy,
    required this.usuariosPorRol,
    required this.productosTotal,
    required this.productosAVenta,
  });

  factory ResumenAdmin.desdeJson(Map<String, dynamic> json) {
    List<Conteo> conteos(String clave) =>
        (json[clave] as List).map((c) => Conteo.desdeJson(c as Map<String, dynamic>)).toList();
    final productos = json['productos'] as Map<String, dynamic>;
    return ResumenAdmin(
      pedidosPorEstado: conteos('pedidosPorEstado'),
      pedidosHoy: json['pedidosHoy'] as int,
      ventasHoy: (json['ventasHoy'] as num).toDouble(),
      usuariosPorRol: conteos('usuariosPorRol'),
      productosTotal: productos['total'] as int,
      productosAVenta: productos['aVenta'] as int,
    );
  }

  final List<Conteo> pedidosPorEstado;
  final int pedidosHoy;
  final double ventasHoy;
  final List<Conteo> usuariosPorRol;
  final int productosTotal;
  final int productosAVenta;
}

class BoticaSimple {
  const BoticaSimple({required this.id, required this.nombre});

  factory BoticaSimple.desdeJson(Map<String, dynamic> json) =>
      BoticaSimple(id: json['id'] as int, nombre: json['nombre'] as String);

  final int id;
  final String nombre;
}

/// Cuenta del personal (Administrador, Encargado o Repartidor).
class MiembroPersonal {
  const MiembroPersonal({
    required this.idUsuario,
    required this.rol,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.telefono,
    required this.correo,
    this.idBotica,
    this.botica,
  });

  factory MiembroPersonal.desdeJson(Map<String, dynamic> json) => MiembroPersonal(
    idUsuario: json['idUsuario'] as int,
    rol: Rol.desdeId((json['rol'] as Map)['id'] as String),
    nombre: json['nombre'] as String,
    apellido: json['apellido'] as String,
    dni: json['dni'] as String,
    telefono: json['telefono'] as String,
    correo: json['correo'] as String,
    idBotica: json['idBotica'] as int?,
    botica: json['botica'] as String?,
  );

  final int idUsuario;
  final Rol rol;
  final String nombre;
  final String apellido;
  final String dni;
  final String telefono;
  final String correo;
  final int? idBotica;
  final String? botica;

  String get nombreCompleto => '$nombre $apellido';
}

/// Datos del formulario de personal (crear o editar).
class DatosPersonal {
  const DatosPersonal({
    required this.nombres,
    required this.apellidos,
    required this.celular,
    required this.rol,
    this.idBotica,
    this.dni,
    this.correo,
    this.contrasena,
  });

  final String nombres;
  final String apellidos;
  final String celular;
  final Rol rol;
  final int? idBotica;

  /// Solo al crear.
  final String? dni;
  final String? correo;
  final String? contrasena;

  Map<String, dynamic> aJson() => {
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'celular': celular.trim(),
    'idRol': rol.id,
    'idBotica': ?idBotica,
    if (dni != null) 'dni': dni!.trim(),
    if (correo != null) 'correo': correo!.trim(),
    'contrasena': ?contrasena,
  };
}

/// Producto en la configuración del catálogo.
class ProductoAdmin {
  const ProductoAdmin({
    required this.idProducto,
    required this.idProductoCore,
    required this.nombre,
    required this.aptoEcommerce,
    required this.requiereReceta,
    this.nombreNortfarma = '',
    this.nombreApp,
    this.idCategoria,
    this.categoria,
    this.presentaciones = const [],
    this.imagenUrl,
  });

  factory ProductoAdmin.desdeJson(Map<String, dynamic> json) => ProductoAdmin(
    idProducto: json['idProducto'] as int,
    idProductoCore: json['idProductoCore'] as String,
    nombre: json['nombre'] as String,
    nombreNortfarma: json['nombreNortfarma'] as String? ?? json['nombre'] as String,
    nombreApp: json['nombreApp'] as String?,
    aptoEcommerce: json['aptoEcommerce'] as bool,
    requiereReceta: json['requiereReceta'] as bool,
    idCategoria: json['idCategoria'] as int?,
    categoria: json['categoria'] as String?,
    presentaciones: (json['presentaciones'] as List?)?.cast<String>() ?? const [],
    imagenUrl: json['imagenUrl'] as String?,
  );

  final int idProducto;
  final String idProductoCore;

  /// Nombre que ve el cliente: [nombreApp] si existe; si no, [nombreNortfarma].
  final String nombre;

  /// Nombre en el sistema de Nortfarma (lo actualiza la sincronización diaria).
  final String nombreNortfarma;

  /// Nombre comercial que puso el Administrador; null = se muestra el de Nortfarma.
  final String? nombreApp;
  final bool aptoEcommerce;
  final bool requiereReceta;

  /// null: producto nuevo de Nortfarma que aún no tiene categoría.
  final int? idCategoria;
  final String? categoria;

  /// Cómo se vende: "Caja x 100 tabletas", "Blíster x 10", "Unidad".
  final List<String> presentaciones;
  final String? imagenUrl;

  bool get esNuevo => idCategoria == null;
}

/// Categoría del catálogo en la gestión del Administrador (incluye las ocultas).
class CategoriaAdmin {
  const CategoriaAdmin({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.activa,
    required this.productos,
  });

  factory CategoriaAdmin.desdeJson(Map<String, dynamic> json) => CategoriaAdmin(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    icono: (json['iconoUrl'] as String? ?? '').replaceFirst('icono://', ''),
    activa: json['activa'] as bool? ?? true,
    productos: json['productos'] as int? ?? 0,
  );

  final int id;
  final String nombre;

  /// Clave del ícono (medicinas, bebe...).
  final String icono;

  /// false: oculta para el cliente (sus productos no aparecen en el catálogo).
  final bool activa;

  /// Productos que tiene, a la venta o no.
  final int productos;
}

/// Resultado de copiar productos y boticas del sistema de Nortfarma.
class ResultadoSincronizacion {
  const ResultadoSincronizacion({
    required this.recibidos,
    required this.nuevos,
    required this.actualizados,
    this.boticasNuevas = 0,
    this.boticasActualizadas = 0,
  });

  factory ResultadoSincronizacion.desdeJson(Map<String, dynamic> json) {
    final productos = json['productos'] as Map<String, dynamic>;
    final boticas = json['boticas'] as Map<String, dynamic>? ?? const {};
    return ResultadoSincronizacion(
      recibidos: productos['recibidos'] as int,
      nuevos: productos['nuevos'] as int,
      actualizados: productos['actualizados'] as int,
      boticasNuevas: boticas['nuevas'] as int? ?? 0,
      boticasActualizadas: boticas['actualizadas'] as int? ?? 0,
    );
  }

  final int recibidos;
  final int nuevos;
  final int actualizados;
  final int boticasNuevas;
  final int boticasActualizadas;
}
