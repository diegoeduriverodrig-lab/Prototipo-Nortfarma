import 'package:flutter/foundation.dart';

import '../core/validadores.dart';
import '../models/pedido.dart';
import '../services/api_service.dart';
import '../services/culqi_service.dart';
import '../services/imagen_service.dart';
import '../services/pedido_service.dart';
import 'carrito_viewmodel.dart';

/// Checkout (RF01, RF02, RF04, RF14): entrega, receta, comprobante y pago.
/// Precios, stock y costo de envío los confirma el backend.
class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._pedidos, this._imagenes, this._culqi, this.carrito) {
    _iniciar();
  }

  final PedidoService _pedidos;
  final ImagenService _imagenes;
  final CulqiService _culqi;
  final CarritoViewModel carrito;

  // Carga inicial
  bool _preparando = true;
  String? _errorCarga;
  List<String> _sinStock = const [];

  // Entrega
  TipoEntrega _entrega = TipoEntrega.delivery;
  List<Direccion> _direcciones = const [];
  List<Botica> _boticas = const [];
  int? _idDireccion;
  int? _idBotica;
  CotizacionEnvio? _cotizacion;
  bool _cotizando = false;
  String? _errorEnvio;

  // Receta
  Uint8List? _recetaVista;
  String? _recetaRuta;
  bool _subiendoReceta = false;

  // Comprobante y pago
  TipoComprobante _comprobante = TipoComprobante.boleta;
  TipoPago? _tipoPago;

  // Confirmación
  bool _enviando = false;
  String? _error;
  PedidoRegistrado? _pedido;
  bool _cerrado = false;

  bool get preparando => _preparando;
  String? get errorCarga => _errorCarga;
  List<String> get sinStock => _sinStock;
  TipoEntrega get entrega => _entrega;
  List<Direccion> get direcciones => _direcciones;
  List<Botica> get boticas => _boticas;
  int? get idDireccion => _idDireccion;
  int? get idBotica => _idBotica;
  CotizacionEnvio? get cotizacion => _cotizacion;
  bool get cotizando => _cotizando;
  String? get errorEnvio => _errorEnvio;
  Uint8List? get recetaVista => _recetaVista;
  bool get recetaLista => _recetaRuta != null;
  bool get subiendoReceta => _subiendoReceta;
  TipoComprobante get comprobante => _comprobante;
  TipoPago? get tipoPago => _tipoPago;
  bool get enviando => _enviando;
  String? get error => _error;
  PedidoRegistrado? get pedido => _pedido;

  /// Con tarjeta y Culqi configurado se piden los datos de la tarjeta;
  /// sin llave de Culqi el pago es simulado.
  bool get pedirTarjeta => _tipoPago == TipoPago.tarjeta && _culqi.habilitado;

  double get subtotal => carrito.subtotal;
  double? get costoEnvio => _entrega == TipoEntrega.recojo ? 0 : _cotizacion?.costo;
  double? get total => costoEnvio == null ? null : subtotal + costoEnvio!;

  /// Lo que falta para poder confirmar; null si está todo listo.
  String? get faltante {
    if (_sinStock.isNotEmpty) return 'Hay productos sin stock suficiente';
    if (_entrega == TipoEntrega.delivery && _idDireccion == null) return 'Elige una dirección';
    if (_entrega == TipoEntrega.delivery && _cotizacion == null) return 'Calculando el envío';
    if (_entrega == TipoEntrega.recojo && _idBotica == null) return 'Elige una botica';
    if (carrito.requiereReceta && !recetaLista) return 'Adjunta tu receta médica';
    if (_tipoPago == null) return 'Elige un método de pago';
    return null;
  }

  Future<void> _iniciar() async {
    _preparando = true;
    _errorCarga = null;
    _notificar();
    try {
      final respuestas = await Future.wait<Object>([
        _pedidos.validarCarrito(carrito.items),
        _pedidos.listarDirecciones(),
        _pedidos.obtenerBoticas(items: carrito.items),
      ], eagerError: true);
      final validacion = respuestas[0] as ValidacionCarrito;
      carrito.aplicarValidacion(validacion);
      _sinStock = validacion.sinStock;
      _direcciones = respuestas[1] as List<Direccion>;
      _boticas = respuestas[2] as List<Botica>;
      if (_direcciones.isNotEmpty) await elegirDireccion(_direcciones.first.id);
    } on ApiException catch (e) {
      _errorCarga = e.mensaje;
    } finally {
      _preparando = false;
      _notificar();
    }
  }

  Future<void> reintentar() => _iniciar();

  void elegirEntrega(TipoEntrega entrega) {
    _entrega = entrega;
    _notificar();
  }

  Future<void> elegirDireccion(int idDireccion) async {
    _idDireccion = idDireccion;
    _cotizacion = null;
    _errorEnvio = null;
    _cotizando = true;
    _notificar();
    try {
      final cotizacion = await _pedidos.cotizarEnvio(idDireccion, carrito.items);
      if (_idDireccion == idDireccion) _cotizacion = cotizacion;
    } on ApiException catch (e) {
      if (_idDireccion == idDireccion) _errorEnvio = e.mensaje;
    } finally {
      if (_idDireccion == idDireccion) {
        _cotizando = false;
        _notificar();
      }
    }
  }

  /// Tras crear una dirección nueva, se agrega a la lista y se elige.
  Future<void> agregarDireccion(Direccion direccion) {
    _direcciones = [direccion, ..._direcciones];
    return elegirDireccion(direccion.id);
  }

  /// Solo se puede recoger en una botica con stock de todo el carrito.
  void elegirBotica(int idBotica) {
    if (!_boticas.any((b) => b.id == idBotica && b.tieneStock)) return;
    _idBotica = idBotica;
    _notificar();
  }

  void elegirComprobante(TipoComprobante comprobante) {
    _comprobante = comprobante;
    _notificar();
  }

  void elegirPago(TipoPago tipoPago) {
    _tipoPago = tipoPago;
    _notificar();
  }

  /// RF14: toma o elige la foto de la receta y la sube.
  Future<void> adjuntarReceta(OrigenImagen origen) async {
    final imagen = await _imagenes.elegir(origen);
    if (imagen == null) return;
    _recetaVista = imagen.bytes;
    _recetaRuta = null;
    _subiendoReceta = true;
    _error = null;
    _notificar();
    try {
      _recetaRuta = await _pedidos.subirReceta(imagen.bytes, imagen.tipo);
    } on ApiException catch (e) {
      _recetaVista = null;
      _error = e.mensaje;
    } finally {
      _subiendoReceta = false;
      _notificar();
    }
  }

  String? validarRuc(String? v) {
    final t = v?.trim() ?? '';
    if (!RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(t)) {
      return 'RUC de 11 dígitos (empieza con 10, 15, 17 o 20)';
    }
    return null;
  }

  String? validarRazonSocial(String? v) => Validadores.requerido(v, 'razón social');

  /// Registra el pedido. Devuelve true si se registró (ver [pedido]), aunque la
  /// tarjeta haya sido rechazada: el pedido queda guardado y se puede reintentar el pago.
  Future<bool> confirmar({
    String? ruc,
    String? razonSocial,
    String? codigoPromocion,
    DatosTarjeta? tarjeta,
  }) async {
    if (_enviando || faltante != null) return false;
    _enviando = true;
    _error = null;
    _notificar();
    try {
      // RF10: la tarjeta se convierte en token directamente con Culqi.
      String? token;
      if (pedirTarjeta) {
        if (tarjeta == null) throw const CulqiException('Ingresa los datos de tu tarjeta.');
        token = await _culqi.crearToken(tarjeta);
      }
      _pedido = await _pedidos.registrarPedido(
        items: carrito.items,
        entrega: _entrega,
        idDireccion: _entrega == TipoEntrega.delivery ? _idDireccion : null,
        idBotica: _entrega == TipoEntrega.recojo ? _idBotica : null,
        comprobante: _comprobante,
        ruc: ruc,
        razonSocial: razonSocial,
        tipoPago: _tipoPago!,
        codigoPromocion: codigoPromocion,
        recetaRuta: _recetaRuta,
        tokenCulqi: token,
      );
      carrito.vaciar();
      return true;
    } on CulqiException catch (e) {
      _error = e.mensaje;
      return false;
    } on ApiException catch (e) {
      _error = e.mensaje;
      final sinStock = e.detalles?['sinStock'];
      if (sinStock is List) {
        _sinStock = [for (final s in sinStock) (s as Map)['nombre'] as String];
      }
      return false;
    } finally {
      _enviando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
