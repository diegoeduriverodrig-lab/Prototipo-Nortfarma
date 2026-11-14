/// Perfiles de acceso (tabla Rol del modelo de datos).
enum Rol {
  administrador('RL01', 'Administrador'),
  encargado('RL02', 'Encargado de botica'),
  repartidor('RL03', 'Repartidor'),
  cliente('RL04', 'Cliente');

  const Rol(this.id, this.nombre);
  final String id;
  final String nombre;

  static Rol desdeId(String id) =>
      values.firstWhere((r) => r.id == id, orElse: () => Rol.cliente);
}

/// Usuario con sesión: datos de Firebase + perfil guardado en MySQL.
class Usuario {
  const Usuario({
    required this.uid,
    required this.correo,
    required this.nombre,
    required this.apellido,
    required this.rol,
    this.dni,
    this.telefono,
    this.idBotica,
  });

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
    uid: json['uid'] as String,
    correo: json['correo'] as String,
    nombre: json['nombre'] as String,
    apellido: json['apellido'] as String,
    rol: Rol.desdeId((json['rol'] as Map)['id'] as String),
    dni: json['dni'] as String?,
    telefono: json['telefono'] as String?,
    idBotica: json['idBotica'] as int?,
  );

  /// Identificador de Firebase Authentication (columna uid_firebase en MySQL).
  final String uid;
  final String correo;
  final String nombre;
  final String apellido;
  final Rol rol;
  final String? dni;
  final String? telefono;

  /// Solo para el Encargado de botica.
  final int? idBotica;

  String get nombreCompleto => '$nombre $apellido'.trim();
  String get primerNombre => nombre.trim().split(' ').first;
}

/// Cuenta de Firebase sin perfil todavía (por ejemplo, primer ingreso con Google).
class CuentaFirebase {
  const CuentaFirebase({required this.uid, required this.correo, this.nombreVisible});

  final String uid;
  final String correo;
  final String? nombreVisible;
}

/// Datos personales que se guardan en la tabla Usuario.
class DatosPerfil {
  const DatosPerfil({
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.celular,
  });

  final String nombres;
  final String apellidos;
  final String dni;
  final String celular;

  Map<String, dynamic> aJson() => {
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'dni': dni.trim(),
    'celular': celular.trim(),
  };
}

/// Formulario de registro de cliente: cuenta (correo y contraseña) + perfil.
class DatosRegistro {
  const DatosRegistro({
    required this.perfil,
    required this.correo,
    required this.contrasena,
  });

  final DatosPerfil perfil;
  final String correo;
  final String contrasena;
}
