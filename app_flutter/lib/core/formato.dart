/// Formatos de texto para mostrar al usuario.
class Formato {
  /// 8.9 -> "S/ 8.90"
  static String soles(double? monto) =>
      monto == null ? 'S/ --' : 'S/ ${monto.toStringAsFixed(2)}';

  /// "11/10/2026 12:22"
  static String fechaHora(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }
}
