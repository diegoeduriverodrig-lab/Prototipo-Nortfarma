import '../models/pedido.dart';
import '../services/pedido_service.dart';
import 'base_viewmodel.dart';

/// Nueva dirección de entrega (RF02). Si se marca en el mapa se guardan las
/// coordenadas exactas y el distrito lo decide Google Maps: solo se acepta si es
/// uno de los distritos con delivery (tabla Ubigeo). Sin mapa, el cliente elige
/// el distrito y el backend usa su centro.
class DireccionFormViewModel extends BaseViewModel {
  DireccionFormViewModel(this._pedidos) {
    _cargarDistritos();
  }

  final PedidoService _pedidos;

  List<Ubigeo> _distritos = const [];
  String? _idUbigeo;
  Direccion? _guardada;
  bool _cargandoDistritos = true;
  UbicacionElegida? _ubicacion;

  /// Punto marcado en el mapa (null si no se marcó).
  UbicacionElegida? get ubicacion => _ubicacion;

  /// Guarda el punto del mapa y elige su distrito si tiene delivery.
  void usarUbicacion(UbicacionElegida ubicacion) {
    _ubicacion = ubicacion;
    final sugerido = _normalizar(ubicacion.distritoSugerido ?? '');
    _idUbigeo = null;
    for (final d in _distritos) {
      if (sugerido.isNotEmpty && _normalizar(d.distrito) == sugerido) _idUbigeo = d.id;
    }
    notifyListeners();
  }

  /// Con el mapa, el distrito lo pone Google y no se cambia a mano.
  bool get distritoDelMapa => _ubicacion != null;

  /// Por qué no se puede usar el punto del mapa; null si se puede.
  String? get avisoCobertura {
    final u = _ubicacion;
    if (u == null || _idUbigeo != null) return null;
    final distrito = u.distritoSugerido?.trim() ?? '';
    final atendidos = _distritos.map((d) => d.distrito).join(', ');
    return distrito.isEmpty
        ? 'No pudimos reconocer el distrito de ese punto. Mueve el pin e inténtalo de nuevo.'
        : 'Aún no hacemos delivery en $distrito. Atendemos: $atendidos.';
  }

  /// "Veintiséis de Octubre" -> "veintiseis de octubre"
  static String _normalizar(String texto) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    final minus = texto.toLowerCase().trim();
    return String.fromCharCodes(minus.runes.map((r) {
      final i = con.indexOf(String.fromCharCode(r));
      return i < 0 ? r : sin.codeUnitAt(i);
    }));
  }

  List<Ubigeo> get distritos => _distritos;
  String? get idUbigeo => _idUbigeo;
  bool get cargandoDistritos => _cargandoDistritos;

  /// Dirección creada; null mientras no se haya guardado.
  Direccion? get guardada => _guardada;

  void elegirDistrito(String? id) {
    if (distritoDelMapa) return;
    _idUbigeo = id;
    notifyListeners();
  }

  String? validarDistrito(String? v) {
    if (avisoCobertura != null) return 'Distrito sin delivery';
    return v == null ? 'Elige tu distrito' : null;
  }

  String? validarDireccion(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Escribe tu dirección';
    if (t.length < 5) return 'Escribe la dirección completa';
    return null;
  }

  Future<void> _cargarDistritos() async {
    await ejecutar(() async => _distritos = await _pedidos.obtenerUbigeos());
    _cargandoDistritos = false;
    notifyListeners();
  }

  Future<bool> guardar(String direccionExacta, String referencia) => ejecutar(() async {
    _guardada = await _pedidos.guardarDireccion(
      idUbigeo: _idUbigeo!,
      direccionExacta: direccionExacta,
      referencia: referencia,
      latitud: _ubicacion?.latitud,
      longitud: _ubicacion?.longitud,
    );
  });
}
