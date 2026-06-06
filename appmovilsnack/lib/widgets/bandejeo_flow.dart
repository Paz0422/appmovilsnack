import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

int _intFirestore(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? fallback;
}

int _intClamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Cerrado si tiene marca de cierre (no usamos solo activo:false para no perderlo en la lista).
bool _bandejeroEstaCerrado(Map<String, dynamic> data) {
  if (data['bandejeoCerrado'] == true) return true;
  if (data['bandejeoCerradoEn'] != null) return true;
  return data['activo'] == false;
}

Map<String, int> _cantidadesBandejaDesdeRonda(
  Map<String, dynamic>? rondaData,
) {
  final map = <String, int>{};
  if (rondaData == null) return map;
  final productos = rondaData['productos'] as List<dynamic>? ?? const [];
  for (final item in productos.whereType<Map<String, dynamic>>()) {
    final id = item['productoId']?.toString();
    if (id == null || id.isEmpty) continue;
    map[id] = _intFirestore(item['cantidadInicial']);
  }
  return map;
}

/// Unidades del stock que vinieron por traspaso (no se editan a mano en bandeja).
int _unidadesPorTraspasoEnStock(Map<String, dynamic> data) {
  final cantidad = _intFirestore(data['cantidad']);
  if (cantidad <= 0) return 0;
  final porTraspasoDoc = _intFirestore(data['cantidadPorTraspaso'], -1);
  if (porTraspasoDoc > 0) {
    return _intClamp(porTraspasoDoc, 0, cantidad);
  }
  final cantidadInicial = data['cantidadInicial'];
  if (cantidadInicial == null) return cantidad;
  final inicial = _intFirestore(cantidadInicial);
  if (cantidad <= inicial) return 0;
  return cantidad - inicial;
}

int _unidadesPropioEnStock(Map<String, dynamic> data) {
  final cantidad = _intFirestore(data['cantidad']);
  if (data['cantidadPropio'] != null) {
    return _intClamp(_intFirestore(data['cantidadPropio']), 0, cantidad);
  }
  return cantidad - _unidadesPorTraspasoEnStock(data);
}

int _totalBandejaDesdePropio(
  int propio,
  int traspasoFijo,
  int maxTotal,
) {
  if (traspasoFijo > 0) {
    return _intClamp(propio + traspasoFijo, traspasoFijo, maxTotal);
  }
  return _intClamp(propio, 1, maxTotal);
}

/// Modelo para productos en la bandeja
class _ProductoBandeja {
  final String productoId;
  final String nombre;
  final double precio;
  int cantidadInicial; // Total en bandeja (propio + traspaso fijo)
  int cantidadSobrante; // Lo que trae de vuelta
  /// Traspaso incluido automáticamente al cargar (no editable).
  int cantidadTraspasoEnBandeja;

  _ProductoBandeja({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidadInicial,
    this.cantidadSobrante = 0,
    this.cantidadTraspasoEnBandeja = 0,
  });

  int get cantidadPropioEnBandeja => _intClamp(
        cantidadInicial - cantidadTraspasoEnBandeja,
        0,
        cantidadInicial,
      );

  int get cantidadVendida => cantidadInicial - cantidadSobrante;
  double get totalVendido => cantidadVendida * precio;
}

/// Casilla para escribir cantidad sin abrir diálogo.
class _CasillaCantidadBandeja extends StatefulWidget {
  final int valor;
  final int maxDisponible;
  final int minValor;
  final bool habilitado;
  final void Function(int cantidad) onConfirmar;

  const _CasillaCantidadBandeja({
    super.key,
    required this.valor,
    required this.maxDisponible,
    this.minValor = 1,
    this.habilitado = true,
    required this.onConfirmar,
  });

  @override
  State<_CasillaCantidadBandeja> createState() => _CasillaCantidadBandejaState();
}

class _CasillaCantidadBandejaState extends State<_CasillaCantidadBandeja> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textoInicial);
    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() {});
        _alCambiarFoco();
      });
  }

  String get _textoInicial {
    if (!widget.habilitado) return '—';
    if (widget.valor > 0) return '${widget.valor}';
    return widget.minValor == 0 ? '0' : '';
  }

  @override
  void didUpdateWidget(covariant _CasillaCantidadBandeja oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.valor != widget.valor) {
      _controller.text = _textoInicial;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_alCambiarFoco);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _alCambiarFoco() {
    if (!_focusNode.hasFocus) _confirmar();
  }

  void _confirmar() {
    if (!widget.habilitado) return;
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      _controller.text = _textoInicial;
      return;
    }
    final cantidad = int.tryParse(texto);
    if (cantidad == null || cantidad < widget.minValor) {
      _controller.text = _textoInicial;
      return;
    }
    final valida = _intClamp(cantidad, widget.minValor, widget.maxDisponible);
    _controller.text = valida > 0 ? '$valida' : '';
    if (valida > 0 && valida != widget.valor) {
      widget.onConfirmar(valida);
    }
  }

  InputBorder _bordeCasilla({required bool enfocado}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: enfocado
            ? _accentColor
            : _accentColor.withValues(alpha: 0.55),
        width: enfocado ? 2 : 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enfocado = _focusNode.hasFocus;
    final borde = _bordeCasilla(enfocado: enfocado);

    return SizedBox(
      width: 52,
      height: 40,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.habilitado,
        readOnly: !widget.habilitado,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _primaryColor,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          hintText: '—',
          border: borde,
          enabledBorder: borde,
          focusedBorder: borde,
          disabledBorder: borde,
          errorBorder: borde,
          focusedErrorBorder: borde,
        ),
        onSubmitted: (_) => _confirmar(),
      ),
    );
  }
}

/// Controles de carga: solo propio editable; traspaso y total visibles.
class _ControlesCargaBandeja extends StatelessWidget {
  final bool modoTraspaso;
  final bool esSumaAdicional;
  final int traspasoFijo;
  final int propioActual;
  final int totalActual;
  final int maxPropio;
  final int maxTotal;
  final int maxAgregar;
  final bool enBandeja;
  final VoidCallback? onQuitarDeBandeja;
  final void Function(int valor) onPropioChanged;
  final VoidCallback onAgregarPrimero;

  const _ControlesCargaBandeja({
    required this.modoTraspaso,
    this.esSumaAdicional = false,
    required this.traspasoFijo,
    required this.propioActual,
    required this.totalActual,
    required this.maxPropio,
    required this.maxTotal,
    this.maxAgregar = 0,
    required this.enBandeja,
    required this.onPropioChanged,
    required this.onAgregarPrimero,
    this.onQuitarDeBandeja,
  });

  @override
  Widget build(BuildContext context) {
    final valorCasilla = esSumaAdicional && enBandeja ? 0 : (enBandeja ? (modoTraspaso ? propioActual : totalActual) : 0);
    final maxCasilla = esSumaAdicional && enBandeja
        ? maxAgregar
        : (modoTraspaso ? maxPropio : maxTotal);
    final etiquetaCasilla = esSumaAdicional && enBandeja
        ? 'Sumar ahora'
        : (modoTraspaso ? 'Lo que carga' : null);

    if (!modoTraspaso) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (enBandeja)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.remove_circle),
                  color: Colors.red,
                  onPressed: onQuitarDeBandeja,
                ),
              if (etiquetaCasilla != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    etiquetaCasilla,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: _secondaryColor,
                    ),
                  ),
                ),
              _CasillaCantidadBandeja(
                valor: valorCasilla,
                maxDisponible: maxCasilla,
                minValor: esSumaAdicional && enBandeja ? 0 : 1,
                onConfirmar: onPropioChanged,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.add_circle),
                color: _accentColor,
                onPressed: enBandeja
                    ? (esSumaAdicional
                        ? (maxAgregar > 0 ? () => onPropioChanged(1) : null)
                        : (totalActual < maxTotal
                            ? () => onPropioChanged(totalActual + 1)
                            : null))
                    : onAgregarPrimero,
              ),
            ],
          ),
          if (esSumaAdicional && enBandeja && maxAgregar > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Puede sumar hasta $maxAgregar u. más (lleva $totalActual)',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.orange[900],
                ),
              ),
            ),
        ],
      );
    }

    final propioParaPreview = esSumaAdicional && enBandeja ? propioActual : propioActual;
    final totalCalculado = _totalBandejaDesdePropio(
      propioParaPreview,
      traspasoFijo,
      maxTotal,
    );
    final puedeSubir = esSumaAdicional && enBandeja
        ? maxAgregar > 0
        : propioActual < maxPropio;
    final puedeBajar = enBandeja && (propioActual > 0 || totalActual > traspasoFijo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (enBandeja)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.remove_circle),
                color: Colors.red,
                onPressed: puedeBajar
                    ? () {
                        if (propioActual <= 0) {
                          onQuitarDeBandeja?.call();
                        } else {
                          onPropioChanged(propioActual - 1);
                        }
                      }
                    : onQuitarDeBandeja,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  etiquetaCasilla ?? 'Lo que carga',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: _secondaryColor,
                  ),
                ),
                _CasillaCantidadBandeja(
                  key: ValueKey('propio-$propioActual-$traspasoFijo-$esSumaAdicional'),
                  valor: valorCasilla,
                  maxDisponible: maxCasilla,
                  minValor: esSumaAdicional && enBandeja
                      ? 0
                      : (maxPropio == 0 ? 0 : 1),
                  habilitado: maxCasilla > 0,
                  onConfirmar: onPropioChanged,
                ),
              ],
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.add_circle),
              color: _accentColor,
              onPressed: enBandeja
                  ? (esSumaAdicional
                      ? (maxAgregar > 0 ? () => onPropioChanged(1) : null)
                      : (puedeSubir
                          ? () => onPropioChanged(propioActual + 1)
                          : null))
                  : (maxPropio > 0
                      ? onAgregarPrimero
                      : () => onPropioChanged(0)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
          ),
          child: Text(
            esSumaAdicional && enBandeja
                ? 'Lleva $totalActual u. ($propioActual + $traspasoFijo traspaso)\n'
                    'Al sumar, el traspaso no se duplica.'
                : enBandeja
                    ? 'Total en bandeja: $totalCalculado u.\n'
                        '($propioActual + $traspasoFijo traspaso automático)'
                    : 'Al cargar: total $totalCalculado u.\n'
                        '($propioActual + $traspasoFijo traspaso automático)',
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green[800],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget principal del flujo de Bandejeo
class BandejeoFlow extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;

  const BandejeoFlow({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
  });

  @override
  State<BandejeoFlow> createState() => _BandejeoFlowState();
}

class _BandejeoFlowState extends State<BandejeoFlow> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  List<_ProductoBandeja> _productosBandeja = [];
  bool _isGuardando = false;
  String? _bandejeroId;
  String? _bandejeroNombre;
  String? _rondaId; // ronda en curso / activa para este bandejero
  /// Efectivo entregado para vuelto al iniciar la primera ronda del turno.
  double _cajaVuelto = 0;
  /// true cuando se entró por "Agregar más cosas" a una ronda en curso.
  bool _actualizandoBandeja = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _siguientePaso() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _anteriorPaso() {
    if (_currentPage > 0) {
      if (_currentPage == 1 && _actualizandoBandeja) {
        _volverAListaBandejeros();
        return;
      }
      if (_currentPage == 1) {
        setState(() => _actualizandoBandeja = false);
      }
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Guarda la ronda y vuelve a la lista de bandejeros (ronda sigue en curso).
  Future<void> _volverAListaBandejeros() async {
    try {
      await _upsertRondaEnCurso();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar la ronda: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _currentPage = 0);
    _pageController.jumpToPage(0);
  }

  double _calcularValorTotal() {
    return _productosBandeja.fold(
      0.0,
      (sum, producto) => sum + (producto.cantidadInicial * producto.precio),
    );
  }

  double _calcularTotalVendido() {
    return _productosBandeja.fold(
      0.0,
      (sum, producto) => sum + producto.totalVendido,
    );
  }

  bool get _muestraFlechaAtrasEnAppBar =>
      _currentPage == 1 || _currentPage == 3;

  void _irASeleccionBandejero() {
    setState(() {
      _bandejeroId = null;
      _bandejeroNombre = null;
      _productosBandeja = [];
      _rondaId = null;
      _cajaVuelto = 0;
      _actualizandoBandeja = false;
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _irAListaTrasRendirRonda() {
    if (!mounted) return;
    setState(() {
      _isGuardando = false;
      _productosBandeja = [];
      _rondaId = null;
      _bandejeroId = null;
      _bandejeroNombre = null;
      _actualizandoBandeja = false;
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ronda rendida correctamente',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentPage == 2 || _currentPage == 3) {
          await _volverAListaBandejeros();
        } else {
          _anteriorPaso();
        }
      },
      child: Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _currentPage == 0
              ? 'Bandejeo'
              : _currentPage == 1
              ? (_actualizandoBandeja
                  ? 'Agregar a la bandeja'
                  : 'Carga de Bandeja')
              : _currentPage == 2
              ? 'Ronda en Curso'
              : 'Rendición de Cuentas',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
        automaticallyImplyLeading:
            _currentPage == 0 || _muestraFlechaAtrasEnAppBar,
        leading: _currentPage == 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
              )
            : _currentPage == 3
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Lista de bandejeros',
                    onPressed: _volverAListaBandejeros,
                  )
                : _currentPage == 1
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _anteriorPaso,
                      )
                    : null,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        physics:
            const NeverScrollableScrollPhysics(), // Deshabilitar swipe manual
        children: [
          _PasoSeleccionBandejero(
            key: const PageStorageKey<String>('bandejeo-paso-bandejeros'),
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            onSeleccionado: _seleccionarBandejero,
            onVerResumenCierre: _mostrarResumenBandejeroCerrado,
          ),
          _PasoCargaBandeja(
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            productosBandeja: _productosBandeja,
            esActualizacionRonda: _actualizandoBandeja,
            onProductosChanged: (productos) {
              setState(() {
                _productosBandeja = productos;
              });
            },
            onSiguiente: () async {
              if (_productosBandeja.isNotEmpty) {
                final eraActualizacion = _actualizandoBandeja;
                try {
                  await _upsertRondaEnCurso();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error guardando ronda: $e',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (!context.mounted) return;
                setState(() => _actualizandoBandeja = false);
                if (eraActualizacion) {
                  await _volverAListaBandejeros();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Bandeja actualizada correctamente',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _siguientePaso();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Debe seleccionar al menos un producto',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          _PasoResumenRonda(
            productosBandeja: _productosBandeja,
            valorTotal: _calcularValorTotal(),
            onVolverLista: _volverAListaBandejeros,
          ),
          _PasoRendicion(
            productosBandeja: _productosBandeja,
            totalVendido: _calcularTotalVendido(),
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            isGuardando: _isGuardando,
            onSobrantesChanged: (productoId, cantidadSobrante) {
              setState(() {
                final producto = _productosBandeja.firstWhere(
                  (p) => p.productoId == productoId,
                );
                producto.cantidadSobrante = cantidadSobrante;
              });
            },
            onConfirmar: () async {
              setState(() {
                _isGuardando = true;
              });

              try {
                await _confirmarVenta();
                if (mounted) {
                  _irAListaTrasRendirRonda();
                }
              } catch (e) {
                setState(() {
                  _isGuardando = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al confirmar venta: $e',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
    );
  }

  DocumentReference<Map<String, dynamic>> _stockRef(String productoId) {
    return FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('stock')
        .doc(productoId);
  }

  /// Descuenta del inventario lo que se asigna a la bandeja (delta respecto a la ronda guardada).
  Future<void> _upsertRondaEnCurso() async {
    if (_bandejeroId == null) {
      throw Exception('Debe seleccionar un bandejero');
    }

    final bandejeroRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(_bandejeroId);

    final rondasRef = bandejeroRef.collection('rondas');
    final bool isNueva = _rondaId == null;
    final rondaRef = isNueva ? rondasRef.doc() : rondasRef.doc(_rondaId);

    _rondaId ??= rondaRef.id;

    final cantidadNueva = {
      for (final p in _productosBandeja) p.productoId: p.cantidadInicial,
    };
    final nombresPorId = {
      for (final p in _productosBandeja) p.productoId: p.nombre,
    };

    final payload = <String, dynamic>{
      'estado': 'en_curso',
      'eventoId': widget.eventoId,
      'sectorId': widget.sectorId,
      'bandejeroId': _bandejeroId,
      'bandejeroNombre': _bandejeroNombre,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'productos': _productosBandeja.map((p) {
        return {
          'productoId': p.productoId,
          'nombre': p.nombre,
          'precio': p.precio,
          'cantidadInicial': p.cantidadInicial,
          'cantidadSobrante': p.cantidadSobrante,
          if (p.cantidadTraspasoEnBandeja > 0)
            'cantidadTraspasoEnBandeja': p.cantidadTraspasoEnBandeja,
        };
      }).toList(),
    };

    if (isNueva) {
      payload['fechaInicio'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final rondaSnap = await tx.get(rondaRef);
      final cantidadAnterior =
          _cantidadesBandejaDesdeRonda(rondaSnap.data());

      final todosLosIds = <String>{
        ...cantidadAnterior.keys,
        ...cantidadNueva.keys,
      };

      for (final productoId in todosLosIds) {
        final anterior = cantidadAnterior[productoId] ?? 0;
        final nuevo = cantidadNueva[productoId] ?? 0;
        final delta = nuevo - anterior;
        if (delta == 0) continue;

        final stockRef = _stockRef(productoId);
        final stockSnap = await tx.get(stockRef);
        final nombre =
            nombresPorId[productoId] ?? productoId;

        if (delta > 0) {
          if (!stockSnap.exists) {
            throw Exception(
              'El producto $nombre no existe en el inventario del sector.',
            );
          }
          final stockActual =
              _intFirestore(stockSnap.data()?['cantidad']);
          if (stockActual < delta) {
            throw Exception(
              'Stock insuficiente para $nombre. '
              'Disponible: $stockActual, necesita: $delta más en bandeja.',
            );
          }
          tx.update(stockRef, {'cantidad': stockActual - delta});
        } else {
          final stockActual = stockSnap.exists
              ? _intFirestore(stockSnap.data()?['cantidad'])
              : 0;
          tx.set(
            stockRef,
            {'cantidad': stockActual - delta},
            SetOptions(merge: true),
          );
        }
      }

      tx.set(rondaRef, payload, SetOptions(merge: true));
    });
  }

  Future<void> _seleccionarBandejero(String id, String nombre) async {
    setState(() {
      _bandejeroId = id;
      _bandejeroNombre = nombre;
      _productosBandeja = [];
      _rondaId = null;
      _cajaVuelto = 0;
      _actualizandoBandeja = false;
    });
    await _handleSeleccionBandejero();
  }

  DocumentReference<Map<String, dynamic>> get _bandejeroRef {
    if (_bandejeroId == null) {
      throw StateError('Bandejero no seleccionado');
    }
    return FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(_bandejeroId);
  }

  Future<double?> _mostrarDialogoCajaVuelto() async {
    final controller = TextEditingController(text: '0');
    final focusNode = FocusNode();

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Caja para vuelto',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Indique cuánto efectivo se entrega al bandejero para vuelto. '
                'Ese monto se sumará al total a entregar al cerrar el bandejeo.',
                style: GoogleFonts.poppins(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monto de la caja',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTap: () {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: _secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final monto = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (monto == null || monto < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Ingrese un monto válido (0 o mayor).',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, monto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
              ),
              child: Text(
                'Continuar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    focusNode.dispose();
    controller.dispose();
    return result;
  }

  Future<bool> _prepararInicioRonda({required bool esPrimeraRonda}) async {
    if (_bandejeroId == null) return false;

    final snap = await _bandejeroRef.get();
    if (!mounted) return false;

    final existente = (snap.data()?['cajaVuelto'] as num?)?.toDouble();
    if (existente != null) {
      setState(() => _cajaVuelto = existente);
      return true;
    }

    if (!esPrimeraRonda) {
      setState(() => _cajaVuelto = 0);
      return true;
    }

    final monto = await _mostrarDialogoCajaVuelto();
    if (!mounted || monto == null) return false;

    await _bandejeroRef.set({'cajaVuelto': monto}, SetOptions(merge: true));
    if (!mounted) return false;
    setState(() => _cajaVuelto = monto);
    return true;
  }

  Future<void> _handleSeleccionBandejero() async {
    if (_bandejeroId == null) return;

    final rondasQuery = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(_bandejeroId)
        .collection('rondas')
        .where('estado', isEqualTo: 'en_curso')
        .limit(1)
        .get();

    if (!mounted) return;

    if (rondasQuery.docs.isEmpty) {
      await _handleBandejeroSinRondaEnCurso();
      return;
    }

    final rondaDoc = rondasQuery.docs.first;
    _rondaId = rondaDoc.id;

    final data = rondaDoc.data();
    final productos = (data['productos'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((p) {
          return _ProductoBandeja(
            productoId: (p['productoId'] as String?) ?? '',
            nombre: (p['nombre'] as String?) ?? '',
            precio: (p['precio'] as num?)?.toDouble() ?? 0.0,
            cantidadInicial: _intFirestore(p['cantidadInicial']),
            cantidadSobrante: _intFirestore(p['cantidadSobrante']),
            cantidadTraspasoEnBandeja: _intFirestore(p['cantidadTraspasoEnBandeja']),
          );
        })
        .where((p) => p.productoId.isNotEmpty)
        .toList();

    setState(() {
      _productosBandeja = productos;
    });

    final action = await showModalBottomSheet<_AccionRonda>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ronda en curso',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bandejero: ${_bandejeroNombre ?? ''}',
                style: GoogleFonts.poppins(color: _secondaryColor),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: Text('Ver lo que llevó', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, _AccionRonda.ver),
              ),
              ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: Text('Agregar más cosas', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, _AccionRonda.agregar),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text('Rendir ronda', style: GoogleFonts.poppins()),
                subtitle: Text(
                  'Cerrar la ronda y registrar ventas',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, _AccionRonda.rendir),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == null) return;

    // Navegación: 0 Selección, 1 Carga, 2 Resumen, 3 Rendición
    switch (action) {
      case _AccionRonda.ver:
        await _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      case _AccionRonda.agregar:
        setState(() => _actualizandoBandeja = true);
        await _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      case _AccionRonda.rendir:
        await _pageController.animateToPage(
          3,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
    }
  }

  Future<void> _handleBandejeroSinRondaEnCurso() async {
    if (_bandejeroId == null) return;

    final rendidasQuery = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(_bandejeroId)
        .collection('rondas')
        .where('estado', isEqualTo: 'rendida')
        .limit(1)
        .get();

    if (!mounted) return;

    if (rendidasQuery.docs.isEmpty) {
      final cerrarSinVentas = await _mostrarMenuBandejeroSinRondas();
      if (!mounted) return;
      if (cerrarSinVentas == true) {
        await _cerrarBandejeoBandejero();
      } else if (cerrarSinVentas == false) {
        if (!await _prepararInicioRonda(esPrimeraRonda: true)) return;
        _siguientePaso();
      }
      return;
    }

    final action = await _mostrarMenuBandejeroTrasRonda();
    if (!mounted) return;
    if (action == null) return;

    switch (action) {
      case _AccionBandejeroTrasRonda.otraRonda:
        setState(() {
          _rondaId = null;
          _productosBandeja = [];
          _actualizandoBandeja = false;
        });
        if (!await _prepararInicioRonda(esPrimeraRonda: false)) return;
        _siguientePaso();
      case _AccionBandejeroTrasRonda.cerrarBandejeo:
        await _cerrarBandejeoBandejero();
    }
  }

  /// `true` = cerrar bandejeo sin ventas, `false` = nueva ronda, `null` = cancelar.
  Future<bool?> _mostrarMenuBandejeroSinRondas() {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _bandejeroNombre ?? 'Bandejero',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sin rondas rendidas. Puede iniciar una ronda o cerrar el bandejeo sin ventas.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _secondaryColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: _accentColor),
                title: Text(
                  'Nueva ronda',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: Colors.red[700]),
                title: Text(
                  'Cerrar bandejeo (sin ventas)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_AccionBandejeroTrasRonda?> _mostrarMenuBandejeroTrasRonda() {
    return showModalBottomSheet<_AccionBandejeroTrasRonda>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _bandejeroNombre ?? 'Bandejero',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ya completó al menos una ronda. ¿Qué desea hacer?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _secondaryColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.replay_rounded, color: _accentColor),
                ),
                title: Text(
                  'Otra ronda',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Cargar una nueva bandeja y salir de nuevo',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                onTap: () =>
                    Navigator.pop(context, _AccionBandejeroTrasRonda.otraRonda),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded, color: Colors.red[700]),
                ),
                title: Text(
                  'Cerrar bandejeo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Finalizar el turno de este bandejero en el sector',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                onTap: () => Navigator.pop(
                  context,
                  _AccionBandejeroTrasRonda.cerrarBandejeo,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cerrarBandejeoBandejero() async {
    if (_bandejeroId == null) return;
    final bandejeroId = _bandejeroId!;
    final nombre = _bandejeroNombre ?? 'Bandejero';

    final enCurso = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(bandejeroId)
        .collection('rondas')
        .where('estado', isEqualTo: 'en_curso')
        .limit(1)
        .get();
    if (!mounted) return;
    if (enCurso.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$nombre tiene una ronda en curso. Rinda la ronda antes de cerrar el bandejeo.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final resumen = await _cargarResumenRondasRendidas(bandejeroId);
    if (!mounted) return;

    final resumenFinal = resumen ??
        const _ResumenVentasBandejero(
          totalVendido: 0,
          cantidadRondas: 0,
          productos: [],
        );

    final bandejeroSnap = await _bandejeroRef.get();
    if (!mounted) return;
    final cajaVuelto =
        (bandejeroSnap.data()?['cajaVuelto'] as num?)?.toDouble() ??
            _cajaVuelto;

    final porcentaje = await _mostrarDialogoResumenCierre(
      nombre: nombre,
      resumen: resumenFinal,
      cajaVuelto: cajaVuelto,
    );
    if (!mounted || porcentaje == null) return;

    final cierre = resumenFinal.toCierreFirestore(
      porcentaje,
      nombreBandejero: nombre,
      cajaVuelto: cajaVuelto,
    );

    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('bandejeros')
          .doc(bandejeroId)
          .set({
        'activo': true,
        'bandejeoCerrado': true,
        'bandejeoCerradoEn': FieldValue.serverTimestamp(),
        'cierreResumen': cierre,
        'ultimaRondaRendida': false,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar el bandejeo: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _bandejeroId = null;
      _bandejeroNombre = null;
      _productosBandeja = [];
      _rondaId = null;
      _cajaVuelto = 0;
    });
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bandejeo de $nombre cerrado. Total a recibir: '
          '\$${(cierre['totalARecibir'] as num).toStringAsFixed(0)}',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Al rendir: devuelve al inventario lo no vendido (sobrante). Lo cargado en bandeja ya se descontó al guardar la ronda.
  Future<void> _confirmarVenta() async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final Map<String, DocumentSnapshot<Map<String, dynamic>>>
          stockSnapshots = {};
      final conSobrante = _productosBandeja
          .where((p) => p.cantidadSobrante > 0)
          .toList();

      for (final producto in conSobrante) {
        final stockRef = _stockRef(producto.productoId);
        stockSnapshots[producto.productoId] = await transaction.get(stockRef);
      }

      // 1. Devolver sobrantes al inventario del sector
      for (final producto in conSobrante) {
        final stockDoc = stockSnapshots[producto.productoId]!;

        if (!stockDoc.exists) {
          throw Exception('El producto ${producto.nombre} no existe en stock');
        }

        final stockData = stockDoc.data() ?? {};
        final cantidadActual = _intFirestore(stockData['cantidad']);
        transaction.update(stockDoc.reference, {
          'cantidad': cantidadActual + producto.cantidadSobrante,
        });
      }

      // 2. Crear documento de transacción
      final transaccionRef = FirebaseFirestore.instance
          .collection('transacciones')
          .doc();

      final totalVendido = _calcularTotalVendido();

      transaction.set(transaccionRef, {
        'eventoId': widget.eventoId,
        'sectorId': widget.sectorId,
        'bandejeroId': _bandejeroId,
        'bandejeroNombre': _bandejeroNombre,
        'rondaId': _rondaId,
        'fecha': FieldValue.serverTimestamp(),
        'metodoPago': 'Bandejeo',
        'montoTotal': totalVendido,
        'productos': _productosBandeja.map((p) {
          return {
            'productoId': p.productoId,
            'nombre': p.nombre,
            'precio': p.precio,
            'cantidadInicial': p.cantidadInicial,
            'cantidadVendida': p.cantidadVendida,
            'cantidadSobrante': p.cantidadSobrante,
            'subtotal': p.totalVendido,
          };
        }).toList(),
      });

      // 3. Marcar ronda como rendida (si existe)
      if (_bandejeroId != null && _rondaId != null) {
        final rondaRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.sectorId)
            .collection('bandejeros')
            .doc(_bandejeroId)
            .collection('rondas')
            .doc(_rondaId);

        transaction.set(rondaRef, {
          'estado': 'rendida',
          'fechaRendicion': FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
          'transaccionId': transaccionRef.id,
          'totalVendido': totalVendido,
          'productos': _productosBandeja.map((p) {
            return {
              'productoId': p.productoId,
              'nombre': p.nombre,
              'precio': p.precio,
              'cantidadInicial': p.cantidadInicial,
              'cantidadVendida': p.cantidadVendida,
              'cantidadSobrante': p.cantidadSobrante,
              'subtotal': p.totalVendido,
            };
          }).toList(),
        }, SetOptions(merge: true));

        final bandejeroRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.sectorId)
            .collection('bandejeros')
            .doc(_bandejeroId);

        transaction.set(
          bandejeroRef,
          {
            'ultimaRondaRendida': true,
            'actualizadoEn': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<_ResumenVentasBandejero?> _cargarResumenRondasRendidas(
    String bandejeroId,
  ) async {
    final qs = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .doc(bandejeroId)
        .collection('rondas')
        .where('estado', isEqualTo: 'rendida')
        .get();

    if (qs.docs.isEmpty) return null;

    final Map<String, _LineaVentaResumen> porProducto = {};
    double total = 0;

    for (final doc in qs.docs) {
      final d = doc.data();
      final totalRonda = (d['totalVendido'] as num?)?.toDouble();
      if (totalRonda != null && totalRonda > 0) {
        total += totalRonda;
      }

      final productos = d['productos'] as List<dynamic>? ?? const [];
      for (final item in productos.whereType<Map<String, dynamic>>()) {
        final key =
            item['productoId']?.toString() ?? item['nombre']?.toString() ?? '';
        final nombre = item['nombre']?.toString() ?? 'Producto';
        final vendido = _intFirestore(item['cantidadVendida']);
        final precio = (item['precio'] as num?)?.toDouble() ?? 0;
        final subtotal =
            (item['subtotal'] as num?)?.toDouble() ?? vendido * precio;

        if (porProducto.containsKey(key)) {
          final prev = porProducto[key]!;
          porProducto[key] = _LineaVentaResumen(
            nombre: prev.nombre,
            cantidadVendida: prev.cantidadVendida + vendido,
            subtotal: prev.subtotal + subtotal,
          );
        } else {
          porProducto[key] = _LineaVentaResumen(
            nombre: nombre,
            cantidadVendida: vendido,
            subtotal: subtotal,
          );
        }
      }
    }

    if (total <= 0 && porProducto.isNotEmpty) {
      total = porProducto.values.fold(0.0, (s, p) => s + p.subtotal);
    }

    final lineas = porProducto.values.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    return _ResumenVentasBandejero(
      totalVendido: total,
      cantidadRondas: qs.docs.length,
      productos: lineas,
    );
  }

  Future<double?> _mostrarDialogoResumenCierre({
    required String nombre,
    required _ResumenVentasBandejero resumen,
    double cajaVuelto = 0,
    bool soloLectura = false,
    Map<String, dynamic>? cierreGuardado,
  }) {
    final pct = (cierreGuardado?['porcentajeComision'] as num?)?.toDouble();
    final comision = (cierreGuardado?['comision'] as num?)?.toDouble();
    final aRecibir = (cierreGuardado?['totalARecibir'] as num?)?.toDouble();
    final caja = (cierreGuardado?['cajaVuelto'] as num?)?.toDouble() ??
        cajaVuelto;

    return showDialog<double>(
      context: context,
      barrierDismissible: soloLectura,
      builder: (ctx) => _DialogoResumenCierreBandejeo(
        nombreBandejero: nombre,
        resumen: resumen,
        cajaVuelto: caja,
        soloLectura: soloLectura,
        porcentajeInicial: pct,
        comisionInicial: comision,
        totalARecibirInicial: aRecibir,
      ),
    );
  }

  Future<void> _mostrarResumenBandejeroCerrado(
    String bandejeroId,
    String nombre,
    Map<String, dynamic> data,
  ) async {
    final cierre = data['cierreResumen'] as Map<String, dynamic>?;
    _ResumenVentasBandejero? resumen =
        _ResumenVentasBandejero.desdeCierreGuardado(cierre);

    resumen ??= await _cargarResumenRondasRendidas(bandejeroId);

    if (!mounted) return;
    if (resumen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay ventas registradas para $nombre.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _mostrarDialogoResumenCierre(
      nombre: nombre,
      resumen: resumen,
      soloLectura: true,
      cierreGuardado: cierre,
    );
  }
}

enum _AccionRonda { ver, agregar, rendir }

enum _AccionBandejeroTrasRonda { otraRonda, cerrarBandejeo }

class _LineaVentaResumen {
  final String nombre;
  final int cantidadVendida;
  final double subtotal;

  const _LineaVentaResumen({
    required this.nombre,
    required this.cantidadVendida,
    required this.subtotal,
  });
}

class _ResumenVentasBandejero {
  final double totalVendido;
  final int cantidadRondas;
  final List<_LineaVentaResumen> productos;

  const _ResumenVentasBandejero({
    required this.totalVendido,
    required this.cantidadRondas,
    required this.productos,
  });

  Map<String, dynamic> toCierreFirestore(
    double porcentajeComision, {
    required String nombreBandejero,
    double cajaVuelto = 0,
  }) {
    final comision = totalVendido * (porcentajeComision / 100);
    return {
      'bandejeroNombre': nombreBandejero,
      'totalVendido': totalVendido,
      'porcentajeComision': porcentajeComision,
      'comision': comision,
      'cajaVuelto': cajaVuelto,
      'totalARecibir': totalVendido + cajaVuelto,
      'cantidadRondas': cantidadRondas,
      'productos': productos
          .map(
            (p) => {
              'nombre': p.nombre,
              'cantidadVendida': p.cantidadVendida,
              'subtotal': p.subtotal,
            },
          )
          .toList(),
    };
  }

  static _ResumenVentasBandejero? desdeCierreGuardado(Map<String, dynamic>? data) {
    if (data == null) return null;
    final productosRaw = data['productos'] as List<dynamic>? ?? const [];
    final productos = productosRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (p) => _LineaVentaResumen(
            nombre: p['nombre']?.toString() ?? 'Producto',
            cantidadVendida: _intFirestore(p['cantidadVendida']),
            subtotal: (p['subtotal'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
    return _ResumenVentasBandejero(
      totalVendido: (data['totalVendido'] as num?)?.toDouble() ?? 0,
      cantidadRondas: _intFirestore(data['cantidadRondas']),
      productos: productos,
    );
  }
}

/// Diálogo de resumen de ventas y comisión al cerrar o consultar bandejero.
class _DialogoResumenCierreBandejeo extends StatefulWidget {
  final String nombreBandejero;
  final _ResumenVentasBandejero resumen;
  final bool soloLectura;
  final double cajaVuelto;
  final double? porcentajeInicial;
  final double? comisionInicial;
  final double? totalARecibirInicial;

  const _DialogoResumenCierreBandejeo({
    required this.nombreBandejero,
    required this.resumen,
    this.cajaVuelto = 0,
    this.soloLectura = false,
    this.porcentajeInicial,
    this.comisionInicial,
    this.totalARecibirInicial,
  });

  @override
  State<_DialogoResumenCierreBandejeo> createState() =>
      _DialogoResumenCierreBandejeoState();
}

class _DialogoResumenCierreBandejeoState
    extends State<_DialogoResumenCierreBandejeo> {
  late final TextEditingController _pctController;
  late double _porcentaje;

  @override
  void initState() {
    super.initState();
    _porcentaje = widget.porcentajeInicial ?? 10;
    _pctController = TextEditingController(
      text: _porcentaje == _porcentaje.roundToDouble()
          ? '${_porcentaje.toInt()}'
          : '$_porcentaje',
    );
  }

  @override
  void dispose() {
    _pctController.dispose();
    super.dispose();
  }

  double get _comision => widget.soloLectura && widget.comisionInicial != null
      ? widget.comisionInicial!
      : widget.resumen.totalVendido * (_porcentaje / 100);

  double get _totalARecibir =>
      widget.soloLectura && widget.totalARecibirInicial != null
          ? widget.totalARecibirInicial!
          : widget.resumen.totalVendido + widget.cajaVuelto;

  void _actualizarPorcentaje(String texto) {
    final valor = double.tryParse(texto.replaceAll(',', '.'));
    if (valor == null || valor < 0 || valor > 100) return;
    setState(() => _porcentaje = valor);
  }

  @override
  Widget build(BuildContext context) {
    final resumen = widget.resumen;

    return AlertDialog(
      title: Text(
        widget.soloLectura
            ? 'Resumen · ${widget.nombreBandejero}'
            : 'Cerrar bandejeo · ${widget.nombreBandejero}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.nombreBandejero,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total vendido',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _secondaryColor,
                      ),
                    ),
                    Text(
                      '\$${resumen.totalVendido.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    Text(
                      '${resumen.cantidadRondas} ronda${resumen.cantidadRondas == 1 ? '' : 's'} rendida${resumen.cantidadRondas == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (resumen.productos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Detalle',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                ...resumen.productos.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.nombre} (${p.cantidadVendida} u.)',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        Text(
                          '\$${p.subtotal.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (!widget.soloLectura) ...[
                TextField(
                  controller: _pctController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Comisión (%) al cerrar bandejeo',
                    hintText: 'Ej: 10',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixText: '%',
                  ),
                  onChanged: _actualizarPorcentaje,
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Comisión: ${widget.porcentajeInicial?.toStringAsFixed(0) ?? _porcentaje.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total vendido',
                          style: GoogleFonts.poppins(),
                        ),
                        Text(
                          '\$${resumen.totalVendido.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Caja para vuelto',
                          style: GoogleFonts.poppins(),
                        ),
                        Text(
                          '\$${widget.cajaVuelto.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total a recibir',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_totalARecibir.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Comisión (referencia para pago al finalizar)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ingrese el porcentaje al cerrar el bandejeo.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _secondaryColor.withValues(alpha: 0.85),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_porcentaje.toStringAsFixed(_porcentaje == _porcentaje.roundToDouble() ? 0 : 1)}% del vendido',
                          style: GoogleFonts.poppins(),
                        ),
                        Text(
                          '\$${_comision.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.soloLectura)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            widget.soloLectura ? null : _porcentaje,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: _primaryColor,
          ),
          child: Text(
            widget.soloLectura ? 'Cerrar' : 'Confirmar cierre',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _PasoSeleccionBandejero extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final Future<void> Function(String bandejeroId, String nombre) onSeleccionado;
  final Future<void> Function(
    String bandejeroId,
    String nombre,
    Map<String, dynamic> data,
  ) onVerResumenCierre;

  const _PasoSeleccionBandejero({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.onSeleccionado,
    required this.onVerResumenCierre,
  });

  @override
  State<_PasoSeleccionBandejero> createState() =>
      _PasoSeleccionBandejeroState();
}

class _PasoSeleccionBandejeroState extends State<_PasoSeleccionBandejero>
    with AutomaticKeepAliveClientMixin {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bandejerosStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bandejerosStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros')
        .snapshots();
  }

  Future<void> _crearBandejero(BuildContext context) async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar bandejero', style: GoogleFonts.poppins()),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre del bandejero'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
              ),
              child: Text('Guardar', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );

    if (nombre == null || nombre.isEmpty) return;

    final bandejerosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('bandejeros');

    final docRef = bandejerosRef.doc();
    await docRef.set({
      'nombre': nombre,
      'creadoEn': FieldValue.serverTimestamp(),
      'activo': true,
    });

    if (context.mounted) {
      await widget.onSeleccionado(docRef.id, nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: _accentColor.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona un bandejero',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bandejerosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: _accentColor),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error cargando bandejeros: ${snapshot.error}',
                      style: GoogleFonts.poppins(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final rawDocs = snapshot.data?.docs ?? const [];
              int cmpNombre(
                QueryDocumentSnapshot<Map<String, dynamic>> a,
                QueryDocumentSnapshot<Map<String, dynamic>> b,
              ) {
                final na = a.data()['nombre']?.toString() ?? '';
                final nb = b.data()['nombre']?.toString() ?? '';
                return na.toLowerCase().compareTo(nb.toLowerCase());
              }

              final activos = rawDocs
                  .where((d) => !_bandejeroEstaCerrado(d.data()))
                  .toList()
                ..sort(cmpNombre);
              final cerrados = rawDocs
                  .where((d) => _bandejeroEstaCerrado(d.data()))
                  .toList()
                ..sort(cmpNombre);

              if (activos.isEmpty && cerrados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 64,
                          color: _secondaryColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay bandejeros aún',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Agrega el primero para comenzar.',
                          style: GoogleFonts.poppins(color: _secondaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget tileBandejero(
                QueryDocumentSnapshot<Map<String, dynamic>> doc, {
                required bool cerrado,
              }) {
                final data = doc.data();
                final nombre = data['nombre'] as String? ?? 'Sin nombre';
                final yaRindio =
                    !cerrado && data['ultimaRondaRendida'] == true;
                final cierre = data['cierreResumen'] as Map<String, dynamic>?;
                final totalCierre =
                    (cierre?['totalVendido'] as num?)?.toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: cerrado ? 1 : 2,
                  color: cerrado
                      ? Colors.grey.withValues(alpha: 0.08)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: cerrado
                        ? BorderSide(
                            color: _secondaryColor.withValues(alpha: 0.35),
                          )
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cerrado
                          ? _secondaryColor.withValues(alpha: 0.15)
                          : _accentColor.withValues(alpha: 0.2),
                      child: Icon(
                        cerrado ? Icons.summarize_outlined : Icons.person,
                        color: cerrado ? _secondaryColor : _accentColor,
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                    subtitle: cerrado
                        ? Text(
                            totalCierre != null
                                ? 'Cerrado · vendió \$${totalCierre.toStringAsFixed(0)} · ver comisión'
                                : 'Cerrado · ver resumen y comisión',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _secondaryColor,
                            ),
                          )
                        : yaRindio
                            ? Text(
                                'Ronda rendida · otra ronda o cerrar bandejeo',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _secondaryColor,
                                ),
                              )
                            : Text(
                                'Nueva ronda',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _secondaryColor.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                    trailing: Icon(
                      cerrado ? Icons.receipt_long : Icons.chevron_right,
                      color: _secondaryColor,
                    ),
                    onTap: () {
                      if (cerrado) {
                        widget.onVerResumenCierre(doc.id, nombre, data);
                      } else {
                        widget.onSeleccionado(doc.id, nombre);
                      }
                    },
                  ),
                );
              }

              Widget encabezadoSeccion(String titulo) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                );
              }

              return ListView(
                key: const PageStorageKey<String>('bandejeo-lista-bandejeros'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (activos.isNotEmpty) ...[
                    encabezadoSeccion('En turno'),
                    ...activos.map((d) => tileBandejero(d, cerrado: false)),
                  ],
                  if (cerrados.isNotEmpty) ...[
                    if (activos.isNotEmpty) const SizedBox(height: 8),
                    encabezadoSeccion('Cerrados (solo consulta)'),
                    ...cerrados.map((d) => tileBandejero(d, cerrado: true)),
                  ],
                ],
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _crearBandejero(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              'Agregar bandejero',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paso 1: Carga de Bandeja
class _PasoCargaBandeja extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final List<_ProductoBandeja> productosBandeja;
  final bool esActualizacionRonda;
  final Function(List<_ProductoBandeja>) onProductosChanged;
  final VoidCallback onSiguiente;

  const _PasoCargaBandeja({
    required this.eventoId,
    required this.sectorId,
    required this.productosBandeja,
    this.esActualizacionRonda = false,
    required this.onProductosChanged,
    required this.onSiguiente,
  });

  @override
  State<_PasoCargaBandeja> createState() => _PasoCargaBandejaState();
}

class _PasoCargaBandejaState extends State<_PasoCargaBandeja> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stockStream;

  @override
  void initState() {
    super.initState();
    _stockStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(widget.sectorId)
        .collection('stock')
        .orderBy('nombre')
        .snapshots();
  }

  void _agregarProducto(_ProductoBandeja producto) {
    final nuevaLista = List<_ProductoBandeja>.from(widget.productosBandeja);
    nuevaLista.add(producto);
    widget.onProductosChanged(nuevaLista);
  }

  void _aplicarCargaEnBandeja({
    required String productoId,
    required String nombre,
    required double precio,
    required int cantidadPropio,
    required int traspasoFijo,
    required int maxTotal,
    required bool yaEnBandeja,
    bool esSumaAdicional = false,
  }) {
    if (esSumaAdicional && yaEnBandeja && cantidadPropio <= 0) return;

    int total;
    if (yaEnBandeja && esSumaAdicional) {
      final actual = widget.productosBandeja
          .firstWhere((p) => p.productoId == productoId);
      if (traspasoFijo > 0) {
        final propioNuevo =
            actual.cantidadPropioEnBandeja + cantidadPropio;
        total = _totalBandejaDesdePropio(
          propioNuevo,
          traspasoFijo,
          maxTotal,
        );
      } else {
        total = _intClamp(
          actual.cantidadInicial + cantidadPropio,
          1,
          maxTotal,
        );
      }
    } else if (traspasoFijo > 0) {
      total = _totalBandejaDesdePropio(
        cantidadPropio,
        traspasoFijo,
        maxTotal,
      );
    } else {
      total = _intClamp(cantidadPropio, 1, maxTotal);
    }
    if (yaEnBandeja) {
      final nuevaLista = widget.productosBandeja.map((p) {
        if (p.productoId == productoId) {
          return _ProductoBandeja(
            productoId: p.productoId,
            nombre: p.nombre,
            precio: p.precio,
            cantidadInicial: total,
            cantidadSobrante: p.cantidadSobrante,
            cantidadTraspasoEnBandeja: traspasoFijo,
          );
        }
        return p;
      }).toList();
      widget.onProductosChanged(nuevaLista);
    } else {
      _agregarProducto(
        _ProductoBandeja(
          productoId: productoId,
          nombre: nombre,
          precio: precio,
          cantidadInicial: total,
          cantidadTraspasoEnBandeja: traspasoFijo,
        ),
      );
    }
  }

  int _traspasoFijoParaProducto(
    _ProductoBandeja? enBandeja,
    int porTraspasoStock,
  ) {
    if (enBandeja != null && enBandeja.cantidadTraspasoEnBandeja > 0) {
      return enBandeja.cantidadTraspasoEnBandeja;
    }
    return porTraspasoStock;
  }

  void _eliminarProducto(String productoId) {
    final nuevaLista = widget.productosBandeja
        .where((p) => p.productoId != productoId)
        .toList();
    widget.onProductosChanged(nuevaLista);
  }

  int _obtenerCantidadEnBandeja(String productoId) {
    final producto = widget.productosBandeja.firstWhere(
      (p) => p.productoId == productoId,
      orElse: () => _ProductoBandeja(
        productoId: productoId,
        nombre: '',
        precio: 0,
        cantidadInicial: 0,
      ),
    );
    return producto.cantidadInicial;
  }

  bool _estaEnBandeja(String productoId) {
    return widget.productosBandeja.any((p) => p.productoId == productoId);
  }

  @override
  Widget build(BuildContext context) {
    final productosBandeja = widget.productosBandeja;
    return Column(
      children: [
        // Resumen de bandeja
        if (productosBandeja.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _accentColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.esActualizacionRonda) ...[
                  Text(
                    'Sume unidades a lo que ya lleva. '
                    'Con traspaso, solo cargue lo propio y el traspaso se suma solo.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _secondaryColor,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Productos en bandeja: ${productosBandeja.length}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: \$${productosBandeja.fold(0.0, (total, p) => total + (p.cantidadInicial * p.precio)).toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ),
        // Lista de productos disponibles
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stockStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: _accentColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error al cargar productos: ${snapshot.error}',
                      style: GoogleFonts.poppins(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: _secondaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay productos con stock disponible',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final productos =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    return _intFirestore(data['cantidad']) > 0;
                  }).toList()..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aNombre = aData['nombre'] as String? ?? '';
                    final bNombre = bData['nombre'] as String? ?? '';
                    return aNombre.compareTo(bNombre);
                  });

              return ListView.builder(
                key: const PageStorageKey<String>('bandejeo-stock-list'),
                padding: const EdgeInsets.all(16),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final productoDoc = productos[index];
                  final data = productoDoc.data() as Map<String, dynamic>;
                  final nombre = data['nombre'] as String? ?? 'Sin nombre';
                  final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
                  final cantidadDisponible = _intFirestore(data['cantidad']);
                  final porTraspasoStock = _unidadesPorTraspasoEnStock(data);
                  final propioStock = _unidadesPropioEnStock(data);
                  final productoId = productoDoc.id;
                  final enBandeja = _estaEnBandeja(productoId);
                  final productoEnBandeja = enBandeja
                      ? widget.productosBandeja
                          .firstWhere((p) => p.productoId == productoId)
                      : null;
                  final traspasoFijo = _traspasoFijoParaProducto(
                    productoEnBandeja,
                    porTraspasoStock,
                  );
                  final modoTraspaso = traspasoFijo > 0;
                  final maxPropio = modoTraspaso
                      ? _intClamp(
                          cantidadDisponible - traspasoFijo,
                          0,
                          cantidadDisponible,
                        )
                      : cantidadDisponible;
                  final cantidadEnBandeja = enBandeja
                      ? _obtenerCantidadEnBandeja(productoId)
                      : 0;
                  final propioEnBandeja = enBandeja
                      ? (productoEnBandeja!.cantidadTraspasoEnBandeja > 0
                          ? productoEnBandeja.cantidadPropioEnBandeja
                          : modoTraspaso
                              ? _intClamp(
                                  cantidadEnBandeja - traspasoFijo,
                                  0,
                                  cantidadEnBandeja,
                                )
                              : cantidadEnBandeja)
                      : 0;
                  final maxAgregar = enBandeja
                      ? _intClamp(
                          cantidadDisponible - cantidadEnBandeja,
                          0,
                          cantidadDisponible,
                        )
                      : cantidadDisponible;
                  final esSumaAdicional = widget.esActualizacionRonda;

                  return Card(
                    key: ValueKey('bandejeo-$productoId'),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: enBandeja ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: enBandeja
                          ? BorderSide(color: _accentColor, width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: enBandeja
                                      ? _accentColor.withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  color:
                                      enBandeja ? _accentColor : _secondaryColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      modoTraspaso
                                          ? 'Precio: \$${precio.toStringAsFixed(0)} · '
                                              'Stock: $cantidadDisponible '
                                              '($propioStock + $porTraspasoStock traspaso)'
                                          : 'Precio: \$${precio.toStringAsFixed(0)} · '
                                              'Stock: $cantidadDisponible',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: _secondaryColor,
                                      ),
                                    ),
                                    if (modoTraspaso) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cargue solo lo que tiene; '
                                        '$traspasoFijo u. de traspaso se suman solas.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.orange[900],
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                    if (enBandeja) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        modoTraspaso
                                            ? 'En bandeja: $cantidadEnBandeja u. '
                                                '($propioEnBandeja + $traspasoFijo traspaso)'
                                            : 'En bandeja: $cantidadEnBandeja u.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _accentColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _ControlesCargaBandeja(
                            modoTraspaso: modoTraspaso,
                            esSumaAdicional: esSumaAdicional,
                            traspasoFijo: traspasoFijo,
                            propioActual: propioEnBandeja,
                            totalActual: cantidadEnBandeja,
                            maxPropio: maxPropio,
                            maxTotal: cantidadDisponible,
                            maxAgregar: maxAgregar,
                            enBandeja: enBandeja,
                            onQuitarDeBandeja: enBandeja
                                ? () {
                                    if (esSumaAdicional) {
                                      if (cantidadEnBandeja <= 1) {
                                        _eliminarProducto(productoId);
                                      } else if (modoTraspaso) {
                                        if (cantidadEnBandeja <= traspasoFijo) {
                                          _eliminarProducto(productoId);
                                        } else {
                                          _aplicarCargaEnBandeja(
                                            productoId: productoId,
                                            nombre: nombre,
                                            precio: precio,
                                            cantidadPropio: propioEnBandeja > 0
                                                ? propioEnBandeja - 1
                                                : 0,
                                            traspasoFijo: traspasoFijo,
                                            maxTotal: cantidadDisponible,
                                            yaEnBandeja: true,
                                          );
                                        }
                                      } else {
                                        _aplicarCargaEnBandeja(
                                          productoId: productoId,
                                          nombre: nombre,
                                          precio: precio,
                                          cantidadPropio:
                                              cantidadEnBandeja - 1,
                                          traspasoFijo: 0,
                                          maxTotal: cantidadDisponible,
                                          yaEnBandeja: true,
                                        );
                                      }
                                    } else if (!modoTraspaso &&
                                        cantidadEnBandeja > 1) {
                                      _aplicarCargaEnBandeja(
                                        productoId: productoId,
                                        nombre: nombre,
                                        precio: precio,
                                        cantidadPropio: cantidadEnBandeja - 1,
                                        traspasoFijo: 0,
                                        maxTotal: cantidadDisponible,
                                        yaEnBandeja: true,
                                      );
                                    } else {
                                      _eliminarProducto(productoId);
                                    }
                                  }
                                : null,
                            onPropioChanged: (valor) {
                              _aplicarCargaEnBandeja(
                                productoId: productoId,
                                nombre: nombre,
                                precio: precio,
                                cantidadPropio: valor,
                                traspasoFijo: traspasoFijo,
                                maxTotal: cantidadDisponible,
                                yaEnBandeja: enBandeja,
                                esSumaAdicional:
                                    esSumaAdicional && enBandeja,
                              );
                            },
                            onAgregarPrimero: () {
                              _aplicarCargaEnBandeja(
                                productoId: productoId,
                                nombre: nombre,
                                precio: precio,
                                cantidadPropio: modoTraspaso && maxPropio == 0
                                    ? 0
                                    : 1,
                                traspasoFijo: traspasoFijo,
                                maxTotal: cantidadDisponible,
                                yaEnBandeja: false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: productosBandeja.isEmpty
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onSiguiente();
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey,
            ),
            child: Text(
              widget.esActualizacionRonda
                  ? 'Actualizar bandeja'
                  : 'Iniciar ronda',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paso 2: Resumen de Ronda
class _PasoResumenRonda extends StatelessWidget {
  final List<_ProductoBandeja> productosBandeja;
  final double valorTotal;
  final VoidCallback onVolverLista;

  const _PasoResumenRonda({
    required this.productosBandeja,
    required this.valorTotal,
    required this.onVolverLista,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header informativo
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accentColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.shopping_basket, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Ronda en Curso',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Valor Total Potencial',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${valorTotal.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Lista de productos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productosBandeja.length,
            itemBuilder: (context, index) {
              final producto = productosBandeja[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fastfood, color: _accentColor, size: 28),
                  ),
                  title: Text(
                    producto.nombre,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Cantidad: ${producto.cantidadInicial}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _secondaryColor,
                    ),
                  ),
                  trailing: Text(
                    '\$${(producto.cantidadInicial * producto.precio).toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _accentColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onVolverLista,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Volver a lista de bandejeros',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Paso 3: Rendición
class _PasoRendicion extends StatelessWidget {
  final List<_ProductoBandeja> productosBandeja;
  final double totalVendido;
  final String eventoId;
  final String sectorId;
  final bool isGuardando;
  final Function(String productoId, int cantidadSobrante) onSobrantesChanged;
  final VoidCallback onConfirmar;

  const _PasoRendicion({
    required this.productosBandeja,
    required this.totalVendido,
    required this.eventoId,
    required this.sectorId,
    required this.isGuardando,
    required this.onSobrantesChanged,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Resumen de ventas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.green.withValues(alpha: 0.1),
          child: Column(
            children: [
              Text(
                'Total Vendido',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${totalVendido.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La comisión se ingresa al cerrar el bandejeo del bandejero, '
                'no en cada ronda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _secondaryColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        // Lista de productos con sobrantes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productosBandeja.length,
            itemBuilder: (context, index) {
              final producto = productosBandeja[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fastfood, color: _accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              producto.nombre,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Llevó: ${producto.cantidadInicial}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendió: ${producto.cantidadVendida} u.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total vendido: \$${producto.totalVendido.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Sobrante',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.red,
                            onPressed: producto.cantidadSobrante > 0
                                ? () => onSobrantesChanged(
                                    producto.productoId,
                                    producto.cantidadSobrante - 1,
                                  )
                                : null,
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${producto.cantidadSobrante}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(Icons.add_circle),
                            color: _accentColor,
                            onPressed: producto.cantidadSobrante <
                                    producto.cantidadInicial
                                ? () => onSobrantesChanged(
                                    producto.productoId,
                                    producto.cantidadSobrante + 1,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Botón Confirmar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isGuardando ? null : onConfirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey,
            ),
            child: isGuardando
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Confirmar Venta',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
