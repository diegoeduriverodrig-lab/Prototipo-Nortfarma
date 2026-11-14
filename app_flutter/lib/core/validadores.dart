/// Validaciones de formularios. Devuelven el mensaje de error o null si es válido.
class Validadores {
  static final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? requerido(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresa tu $campo';
    return null;
  }

  static String? correo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo electrónico';
    if (!_correo.hasMatch(v)) return 'El correo no es válido';
    return null;
  }

  /// Firebase exige como mínimo 6 caracteres.
  static String? contrasena(String? valor) {
    if (valor == null || valor.isEmpty) return 'Ingresa tu contraseña';
    if (valor.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  static String? confirmarContrasena(String? valor, String original) {
    if (valor == null || valor.isEmpty) return 'Confirma tu contraseña';
    if (valor != original) return 'Las contraseñas no coinciden';
    return null;
  }

  /// DNI peruano: 8 dígitos.
  static String? dni(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu DNI';
    if (!RegExp(r'^\d{8}$').hasMatch(v)) return 'El DNI debe tener 8 dígitos';
    return null;
  }

  /// Número de tarjeta: 13 a 19 dígitos y dígito verificador correcto (algoritmo de Luhn).
  static String? numeroTarjeta(String? valor) {
    final digitos = (valor ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return 'Ingresa el número de la tarjeta';
    if (digitos.length < 13 || digitos.length > 19) return 'Número de tarjeta incompleto';
    var suma = 0;
    for (var i = 0; i < digitos.length; i++) {
      var d = int.parse(digitos[digitos.length - 1 - i]);
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      suma += d;
    }
    return suma % 10 == 0 ? null : 'El número de tarjeta no es válido';
  }

  /// Vencimiento "MM/AA", no vencido. [hoy] permite probarlo con una fecha fija.
  static String? vencimiento(String? valor, {DateTime? hoy}) {
    final partes = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(valor?.trim() ?? '');
    if (partes == null) return 'Usa el formato MM/AA';
    final mes = int.parse(partes.group(1)!);
    final anio = 2000 + int.parse(partes.group(2)!);
    if (mes < 1 || mes > 12) return 'Mes no válido';
    final ahora = hoy ?? DateTime.now();
    if (anio < ahora.year || (anio == ahora.year && mes < ahora.month)) return 'La tarjeta está vencida';
    return null;
  }

  static String? cvv(String? valor) {
    if (!RegExp(r'^\d{3,4}$').hasMatch(valor?.trim() ?? '')) return 'CVV de 3 o 4 dígitos';
    return null;
  }

  /// Celular peruano: 9 dígitos y empieza con 9.
  static String? celular(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu celular';
    if (!RegExp(r'^9\d{8}$').hasMatch(v)) {
      return 'Debe tener 9 dígitos y empezar con 9';
    }
    return null;
  }
}
