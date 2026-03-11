import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

/// Modelo para productos en la bandeja
class _ProductoBandeja {
  final String productoId;
  final String nombre;
  final double precio;
  int cantidadInicial; // Lo que lleva
  int cantidadSobrante; // Lo que trae de vuelta

  _ProductoBandeja({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidadInicial,
    this.cantidadSobrante = 0,
  });

  int get cantidadVendida => cantidadInicial - cantidadSobrante;
  double get totalVendido => cantidadVendida * precio;
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
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

  double _calcularComision() {
    return _calcularTotalVendido() * 0.10; // 10% de comisión
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _currentPage == 0
              ? 'Bandejeo'
              : _currentPage == 1
              ? 'Carga de Bandeja'
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
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _anteriorPaso,
              )
            : null,
        actions: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Cambiar bandejero / Entrar con otra cuenta',
              onPressed: () {
                setState(() {
                  _bandejeroId = null;
                  _bandejeroNombre = null;
                  _productosBandeja = [];
                  _rondaId = null;
                  _currentPage = 0;
                });
                _pageController.jumpToPage(0);
              },
            ),
        ],
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
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            onSeleccionado: (id, nombre) async {
              setState(() {
                _bandejeroId = id;
                _bandejeroNombre = nombre;
                _productosBandeja = [];
                _rondaId = null;
              });

              await _handleSeleccionBandejero();
            },
          ),
          _PasoCargaBandeja(
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            productosBandeja: _productosBandeja,
            onProductosChanged: (productos) {
              setState(() {
                _productosBandeja = productos;
              });
            },
            onSiguiente: () async {
              if (_productosBandeja.isNotEmpty) {
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
                _siguientePaso();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Debes seleccionar al menos un producto',
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
            onFinalizar: _siguientePaso,
          ),
          _PasoRendicion(
            productosBandeja: _productosBandeja,
            totalVendido: _calcularTotalVendido(),
            comision: _calcularComision(),
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
                  Navigator.of(context).pop(true); // Retornar éxito
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
    );
  }

  Future<void> _upsertRondaEnCurso() async {
    if (_bandejeroId == null) {
      throw Exception('Debes seleccionar un bandejero');
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
        };
      }).toList(),
    };

    if (isNueva) {
      payload['fechaInicio'] = FieldValue.serverTimestamp();
    }

    await rondaRef.set(payload, SetOptions(merge: true));
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
      // No hay ronda en curso: ir directo a cargar bandeja.
      _siguientePaso();
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
            cantidadInicial: (p['cantidadInicial'] as int?) ?? 0,
            cantidadSobrante: (p['cantidadSobrante'] as int?) ?? 0,
          );
        })
        .where((p) => p.productoId.isNotEmpty)
        .toList();

    setState(() {
      _productosBandeja = productos;
    });

    final action = await showModalBottomSheet<_AccionRonda>(
      context: context,
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
                title: Text('Rendir ahora', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, _AccionRonda.rendir),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    // Navegación: 0 Selección, 1 Carga, 2 Resumen, 3 Rendición
    switch (action ?? _AccionRonda.ver) {
      case _AccionRonda.ver:
        await _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      case _AccionRonda.agregar:
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

  /// Transacción final para actualizar stock y crear transacción
  Future<void> _confirmarVenta() async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // ===== FASE DE LECTURA: Obtener todos los snapshots necesarios =====
      final Map<String, DocumentSnapshot> stockSnapshots = {};
      final List<_ProductoBandeja> productosAVender = _productosBandeja
          .where((p) => p.cantidadVendida > 0)
          .toList();

      // Leer todos los documentos de stock necesarios
      for (final producto in productosAVender) {
        final stockRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.sectorId)
            .collection('stock')
            .doc(producto.productoId);

        final stockDoc = await transaction.get(stockRef);
        stockSnapshots[producto.productoId] = stockDoc;
      }

      // ===== FASE DE ESCRITURA: Actualizar stocks y crear transacción =====

      // 1. Actualizar todos los stocks
      for (final producto in productosAVender) {
        final stockDoc = stockSnapshots[producto.productoId]!;

        if (!stockDoc.exists) {
          throw Exception('El producto ${producto.nombre} no existe en stock');
        }

        final stockData = stockDoc.data() as Map<String, dynamic>;
        final cantidadActual = stockData['cantidad'] as int? ?? 0;

        if (cantidadActual < producto.cantidadVendida) {
          throw Exception(
            'Stock insuficiente para ${producto.nombre}. Disponible: $cantidadActual, Vendido: ${producto.cantidadVendida}',
          );
        }

        final stockRef = stockDoc.reference;
        transaction.update(stockRef, {
          'cantidad': cantidadActual - producto.cantidadVendida,
        });
      }

      // 2. Crear documento de transacción
      final transaccionRef = FirebaseFirestore.instance
          .collection('transacciones')
          .doc();

      final totalVendido = _calcularTotalVendido();
      final comision = _calcularComision();

      transaction.set(transaccionRef, {
        'eventoId': widget.eventoId,
        'sectorId': widget.sectorId,
        'bandejeroId': _bandejeroId,
        'bandejeroNombre': _bandejeroNombre,
        'rondaId': _rondaId,
        'fecha': FieldValue.serverTimestamp(),
        'metodoPago': 'Bandejeo',
        'montoTotal': totalVendido,
        'comision': comision,
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
          'comision': comision,
          'totalAPagar': totalVendido - comision,
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
      }
    });
  }
}

enum _AccionRonda { ver, agregar, rendir }

class _PasoSeleccionBandejero extends StatelessWidget {
  final String eventoId;
  final String sectorId;
  final void Function(String bandejeroId, String nombre) onSeleccionado;

  const _PasoSeleccionBandejero({
    required this.eventoId,
    required this.sectorId,
    required this.onSeleccionado,
  });

  Future<void> _crearBandejero(BuildContext context) async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar bandejero', style: GoogleFonts.poppins()),
          content: TextField(
            controller: controller,
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
        .doc(eventoId)
        .collection('sectores')
        .doc(sectorId)
        .collection('bandejeros');

    final docRef = bandejerosRef.doc();
    await docRef.set({
      'nombre': nombre,
      'creadoEn': FieldValue.serverTimestamp(),
      'activo': true,
    });

    if (context.mounted) {
      onSeleccionado(docRef.id, nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bandejerosStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .doc(sectorId)
        .collection('bandejeros')
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: _accentColor.withOpacity(0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona con qué persona trabajar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cada bandejero tiene su cuenta por separado. Puedes agregar personas abajo y, en cualquier paso, usar "Cambiar bandejero" para salir y entrar con otra cuenta.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _secondaryColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: bandejerosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
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

              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 64,
                          color: _secondaryColor.withOpacity(0.6),
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = data['nombre'] as String? ?? 'Sin nombre';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _accentColor.withOpacity(0.2),
                        child: Icon(Icons.person, color: _accentColor),
                      ),
                      title: Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: _secondaryColor,
                      ),
                      onTap: () => onSeleccionado(doc.id, nombre),
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
                color: Colors.black.withOpacity(0.08),
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
class _PasoCargaBandeja extends StatelessWidget {
  final String eventoId;
  final String sectorId;
  final List<_ProductoBandeja> productosBandeja;
  final Function(List<_ProductoBandeja>) onProductosChanged;
  final VoidCallback onSiguiente;

  const _PasoCargaBandeja({
    required this.eventoId,
    required this.sectorId,
    required this.productosBandeja,
    required this.onProductosChanged,
    required this.onSiguiente,
  });

  void _agregarProducto(_ProductoBandeja producto) {
    final nuevaLista = List<_ProductoBandeja>.from(productosBandeja);
    nuevaLista.add(producto);
    onProductosChanged(nuevaLista);
  }

  void _actualizarCantidad(String productoId, int nuevaCantidad) {
    final nuevaLista = productosBandeja.map((p) {
      if (p.productoId == productoId) {
        return _ProductoBandeja(
          productoId: p.productoId,
          nombre: p.nombre,
          precio: p.precio,
          cantidadInicial: nuevaCantidad,
        );
      }
      return p;
    }).toList();
    onProductosChanged(nuevaLista);
  }

  void _eliminarProducto(String productoId) {
    final nuevaLista = productosBandeja
        .where((p) => p.productoId != productoId)
        .toList();
    onProductosChanged(nuevaLista);
  }

  int _obtenerCantidadEnBandeja(String productoId) {
    final producto = productosBandeja.firstWhere(
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
    return productosBandeja.any((p) => p.productoId == productoId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Resumen de bandeja
        if (productosBandeja.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _accentColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Productos en Bandeja: ${productosBandeja.length}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      'Total: \$${productosBandeja.fold(0.0, (sum, p) => sum + (p.cantidadInicial * p.precio)).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Lista de productos disponibles
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('eventos')
                .doc(eventoId)
                .collection('sectores')
                .doc(sectorId)
                .collection('stock')
                .orderBy('nombre')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
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
                        color: _secondaryColor.withOpacity(0.5),
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
                    final data = doc.data() as Map<String, dynamic>;
                    final cantidad = data['cantidad'] as int? ?? 0;
                    return cantidad > 0;
                  }).toList()..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aNombre = aData['nombre'] as String? ?? '';
                    final bNombre = bData['nombre'] as String? ?? '';
                    return aNombre.compareTo(bNombre);
                  });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final productoDoc = productos[index];
                  final data = productoDoc.data() as Map<String, dynamic>;
                  final nombre = data['nombre'] as String? ?? 'Sin nombre';
                  final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
                  final cantidadDisponible = data['cantidad'] as int? ?? 0;
                  final productoId = productoDoc.id;
                  final enBandeja = _estaEnBandeja(productoId);
                  final cantidadEnBandeja = enBandeja
                      ? _obtenerCantidadEnBandeja(productoId)
                      : 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: enBandeja ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: enBandeja
                          ? BorderSide(color: _accentColor, width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: enBandeja
                              ? _accentColor.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.fastfood,
                          color: enBandeja ? _accentColor : _secondaryColor,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Precio: \$${precio.toStringAsFixed(0)} | Stock: $cantidadDisponible',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                          if (enBandeja)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'En bandeja: $cantidadEnBandeja',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: enBandeja
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  color: Colors.red,
                                  onPressed: cantidadEnBandeja > 1
                                      ? () => _actualizarCantidad(
                                          productoId,
                                          cantidadEnBandeja - 1,
                                        )
                                      : () => _eliminarProducto(productoId),
                                ),
                                Text(
                                  '$cantidadEnBandeja',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: _accentColor,
                                  onPressed:
                                      cantidadEnBandeja < cantidadDisponible
                                      ? () => _actualizarCantidad(
                                          productoId,
                                          cantidadEnBandeja + 1,
                                        )
                                      : null,
                                ),
                              ],
                            )
                          : IconButton(
                              icon: Icon(Icons.add_circle, color: _accentColor),
                              onPressed: () {
                                _agregarProducto(
                                  _ProductoBandeja(
                                    productoId: productoId,
                                    nombre: nombre,
                                    precio: precio,
                                    cantidadInicial: 1,
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Botón Iniciar Ronda
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: productosBandeja.isNotEmpty ? onSiguiente : null,
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
              'Iniciar Ronda',
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
  final VoidCallback onFinalizar;

  const _PasoResumenRonda({
    required this.productosBandeja,
    required this.valorTotal,
    required this.onFinalizar,
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
                      color: _accentColor.withOpacity(0.2),
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
        // Botón Finalizar Ronda
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onFinalizar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Finalizar Ronda y Rendir',
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

/// Paso 3: Rendición
class _PasoRendicion extends StatelessWidget {
  final List<_ProductoBandeja> productosBandeja;
  final double totalVendido;
  final double comision;
  final String eventoId;
  final String sectorId;
  final bool isGuardando;
  final Function(String productoId, int cantidadSobrante) onSobrantesChanged;
  final VoidCallback onConfirmar;

  const _PasoRendicion({
    required this.productosBandeja,
    required this.totalVendido,
    required this.comision,
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
          color: Colors.green.withOpacity(0.1),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Comisión (10%)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondaryColor,
                        ),
                      ),
                      Text(
                        '\$${comision.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Total a Pagar',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondaryColor,
                        ),
                      ),
                      Text(
                        '\$${(totalVendido - comision).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Llevó: ${producto.cantidadInicial}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _secondaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vendió: ${producto.cantidadVendida}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Sobrante',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _secondaryColor,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle),
                                    color: Colors.red,
                                    onPressed: producto.cantidadSobrante > 0
                                        ? () => onSobrantesChanged(
                                            producto.productoId,
                                            producto.cantidadSobrante - 1,
                                          )
                                        : null,
                                  ),
                                  Container(
                                    width: 50,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${producto.cantidadSobrante}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    color: _accentColor,
                                    onPressed:
                                        producto.cantidadSobrante <
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
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _secondaryColor,
                            ),
                          ),
                          Text(
                            '\$${producto.totalVendido.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _accentColor,
                            ),
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
                color: Colors.black.withOpacity(0.1),
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
