// Archivo: lib/widgets/transaction_reports.dart
// Reportes de Transacciones - Monitoreo de ventas por eventos

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TransactionReports extends StatefulWidget {
  const TransactionReports({super.key});

  @override
  State<TransactionReports> createState() => _TransactionReportsState();
}

class _TransactionReportsState extends State<TransactionReports> {
  final TextEditingController _searchController = TextEditingController();
  
  String? _eventoSeleccionadoId;
  String? _eventoSeleccionadoNombre;
  
  List<Map<String, dynamic>> _transaccionesData = [];
  List<Map<String, dynamic>> _transaccionesFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  String _ordenarPor = 'fecha'; // 'fecha', 'monto', 'evento'
  bool _ordenDescendente = true;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _cargarReportesTransacciones();
    _searchController.addListener(_filtrarTransacciones);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarReportesTransacciones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener todas las transacciones
      QuerySnapshot transaccionesSnapshot;
      
      if (_eventoSeleccionadoId != null) {
        transaccionesSnapshot = await FirebaseFirestore.instance
            .collection('transacciones')
            .where('eventoId', isEqualTo: _eventoSeleccionadoId)
            .orderBy('fecha', descending: true)
            .get();
      } else {
        transaccionesSnapshot = await FirebaseFirestore.instance
            .collection('transacciones')
            .orderBy('fecha', descending: true)
            .get();
      }

      // Obtener información de eventos y sectores de forma eficiente
      final eventosSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .get();

      final Map<String, String> eventosMap = {};
      final Map<String, Map<String, String>> sectoresMap = {}; // eventoId -> {sectorId: nombre}

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoData = eventoDoc.data();
        eventosMap[eventoId] = eventoData['nombre']?.toString() ?? 'Sin nombre';
        
        // Precargar todos los sectores de cada evento
        sectoresMap[eventoId] = {};
        try {
          final sectoresSnapshot = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .get();
          
          for (var sectorDoc in sectoresSnapshot.docs) {
            final sectorData = sectorDoc.data();
            sectoresMap[eventoId]![sectorDoc.id] = 
                sectorData['nombre']?.toString() ?? 'Sin sector';
          }
        } catch (e) {
          // Si hay error, continuar sin los sectores de ese evento
        }
      }

      final List<Map<String, dynamic>> transaccionesData = [];

      for (var transDoc in transaccionesSnapshot.docs) {
        final transData = transDoc.data() as Map<String, dynamic>;
        final eventoId = transData['eventoId']?.toString() ?? '';
        final sectorId = transData['sectorId']?.toString() ?? '';
        
        // Obtener nombre del sector desde el mapa precargado
        String sectorNombre = 'Sin sector';
        if (eventoId.isNotEmpty && 
            sectorId.isNotEmpty && 
            sectoresMap.containsKey(eventoId) &&
            sectoresMap[eventoId]!.containsKey(sectorId)) {
          sectorNombre = sectoresMap[eventoId]![sectorId]!;
        }

        final fecha = transData['fecha'];
        DateTime fechaDateTime;
        
        if (fecha is Timestamp) {
          fechaDateTime = fecha.toDate();
        } else if (fecha is DateTime) {
          fechaDateTime = fecha;
        } else {
          fechaDateTime = DateTime.now();
        }

        transaccionesData.add({
          'id': transDoc.id,
          'eventoId': eventoId,
          'eventoNombre': eventosMap[eventoId] ?? 'Sin evento',
          'sectorId': sectorId,
          'sectorNombre': sectorNombre,
          'vendedorNombre': transData['vendedorNombre']?.toString() ?? 'Sin vendedor',
          'montoTotal': (transData['montoTotal'] as num?)?.toDouble() ?? 0.0,
          'metodoPago': transData['metodoPago']?.toString() ?? 'No especificado',
          'fecha': fechaDateTime,
        });
      }

      // Ordenar según la selección
      _ordenarTransacciones(transaccionesData);

      setState(() {
        _transaccionesData = transaccionesData;
        _transaccionesFiltrados = transaccionesData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar reportes de transacciones: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _ordenarTransacciones(List<Map<String, dynamic>> lista) {
    lista.sort((a, b) {
      int comparacion = 0;
      
      switch (_ordenarPor) {
        case 'fecha':
          comparacion = a['fecha'].compareTo(b['fecha']);
          break;
        case 'monto':
          comparacion = (a['montoTotal'] as double).compareTo(b['montoTotal'] as double);
          break;
        case 'evento':
          comparacion = (a['eventoNombre'] as String).compareTo(b['eventoNombre'] as String);
          break;
        default:
          comparacion = 0;
      }
      
      return _ordenDescendente ? -comparacion : comparacion;
    });
  }

  void _filtrarTransacciones() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _transaccionesFiltrados = List.from(_transaccionesData);
      } else {
        _transaccionesFiltrados = _transaccionesData.where((item) {
          final eventoNombre = item['eventoNombre']?.toString().toLowerCase() ?? '';
          final sectorNombre = item['sectorNombre']?.toString().toLowerCase() ?? '';
          final vendedorNombre = item['vendedorNombre']?.toString().toLowerCase() ?? '';
          final metodoPago = item['metodoPago']?.toString().toLowerCase() ?? '';
          
          return eventoNombre.contains(query) ||
                 sectorNombre.contains(query) ||
                 vendedorNombre.contains(query) ||
                 metodoPago.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _seleccionarEvento() async {
    final eventosSnapshot = await FirebaseFirestore.instance
        .collection('eventos')
        .orderBy('nombre')
        .get();

    if (eventosSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay eventos disponibles',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final evento = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Seleccionar Evento',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: eventosSnapshot.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    'Todos los eventos',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos'});
                  },
                );
              }

              final eventoDoc = eventosSnapshot.docs[index - 1];
              final eventoData = eventoDoc.data();
              final eventoNombre = eventoData['nombre']?.toString() ?? 'Sin nombre';

              return ListTile(
                title: Text(eventoNombre, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context, {
                    'id': eventoDoc.id,
                    'nombre': eventoNombre,
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    if (evento != null) {
      setState(() {
        _eventoSeleccionadoId = evento['id']?.isEmpty == true ? null : evento['id'];
        _eventoSeleccionadoNombre = evento['nombre'];
      });
      await _cargarReportesTransacciones();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _eventoSeleccionadoId = null;
      _eventoSeleccionadoNombre = null;
    });
    _cargarReportesTransacciones();
  }

  void _cambiarOrden(String nuevoOrden) {
    setState(() {
      if (_ordenarPor == nuevoOrden) {
        _ordenDescendente = !_ordenDescendente;
      } else {
        _ordenarPor = nuevoOrden;
        _ordenDescendente = true;
      }
      _ordenarTransacciones(_transaccionesFiltrados);
    });
  }

  Map<String, dynamic> _calcularEstadisticas() {
    if (_transaccionesFiltrados.isEmpty) {
      return {
        'totalTransacciones': 0,
        'montoTotal': 0.0,
        'promedioPorTransaccion': 0.0,
        'metodoPagoMasUsado': 'N/A',
      };
    }

    final totalTransacciones = _transaccionesFiltrados.length;
    final montoTotal = _transaccionesFiltrados.fold<double>(
      0.0,
      (sum, item) => sum + (item['montoTotal'] as double? ?? 0.0),
    );
    final promedioPorTransaccion = montoTotal / totalTransacciones;

    // Método de pago más usado
    final Map<String, int> metodosPago = {};
    for (var trans in _transaccionesFiltrados) {
      final metodo = trans['metodoPago']?.toString() ?? 'No especificado';
      metodosPago[metodo] = (metodosPago[metodo] ?? 0) + 1;
    }
    
    String metodoPagoMasUsado = 'N/A';
    if (metodosPago.isNotEmpty) {
      metodoPagoMasUsado = metodosPago.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return {
      'totalTransacciones': totalTransacciones,
      'montoTotal': montoTotal,
      'promedioPorTransaccion': promedioPorTransaccion,
      'metodoPagoMasUsado': metodoPagoMasUsado,
    };
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatearMonto(double monto) {
    return '\$${monto.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    final estadisticas = _calcularEstadisticas();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Reportes de Transacciones',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportesTransacciones,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: secondaryColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _cargarReportesTransacciones,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: primaryColor,
                          ),
                          child: Text(
                            'Reintentar',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Filtros y búsqueda
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Filtro de evento
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _seleccionarEvento,
                                  icon: const Icon(Icons.event, size: 18),
                                  label: Text(
                                    _eventoSeleccionadoNombre ?? 'Todos los eventos',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withOpacity(0.1),
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              if (_eventoSeleccionadoId != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _limpiarFiltros,
                                  tooltip: 'Limpiar filtros',
                                  color: primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Búsqueda
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Buscar por evento, sector, vendedor o método de pago...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Ordenar
                          Row(
                            children: [
                              Text(
                                'Ordenar por: ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: secondaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _OrderButton(
                                label: 'Fecha',
                                activo: _ordenarPor == 'fecha',
                                descendente: _ordenarPor == 'fecha' && _ordenDescendente,
                                onTap: () => _cambiarOrden('fecha'),
                              ),
                              const SizedBox(width: 8),
                              _OrderButton(
                                label: 'Monto',
                                activo: _ordenarPor == 'monto',
                                descendente: _ordenarPor == 'monto' && _ordenDescendente,
                                onTap: () => _cambiarOrden('monto'),
                              ),
                              const SizedBox(width: 8),
                              _OrderButton(
                                label: 'Evento',
                                activo: _ordenarPor == 'evento',
                                descendente: _ordenarPor == 'evento' && _ordenDescendente,
                                onTap: () => _cambiarOrden('evento'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Estadísticas
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            icon: Icons.receipt_long,
                            label: 'Transacciones',
                            value: estadisticas['totalTransacciones'].toString(),
                            color: primaryColor,
                          ),
                          _StatCard(
                            icon: Icons.attach_money,
                            label: 'Total',
                            value: _formatearMonto(estadisticas['montoTotal'] as double),
                            color: Colors.green,
                          ),
                          _StatCard(
                            icon: Icons.trending_up,
                            label: 'Promedio',
                            value: _formatearMonto(estadisticas['promedioPorTransaccion'] as double),
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),

                    // Lista de transacciones
                    Expanded(
                      child: _transaccionesFiltrados.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: secondaryColor.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay transacciones disponibles',
                                      style: GoogleFonts.poppins(
                                        color: secondaryColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _transaccionesFiltrados.length,
                              itemBuilder: (context, index) {
                                final trans = _transaccionesFiltrados[index];
                                final monto = trans['montoTotal'] as double? ?? 0.0;
                                final fecha = trans['fecha'] as DateTime;
                                final eventoNombre = trans['eventoNombre'] ?? 'Sin evento';
                                final sectorNombre = trans['sectorNombre'] ?? 'Sin sector';
                                final vendedorNombre = trans['vendedorNombre'] ?? 'Sin vendedor';
                                final metodoPago = trans['metodoPago'] ?? 'No especificado';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.payment,
                                        color: accentColor,
                                        size: 28,
                                      ),
                                    ),
                                    title: Text(
                                      _formatearMonto(monto),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: primaryColor,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          eventoNombre,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$sectorNombre • $vendedorNombre',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: secondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_formatearFecha(fecha)} • $metodoPago',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: secondaryColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OrderButton extends StatelessWidget {
  final String label;
  final bool activo;
  final bool descendente;
  final VoidCallback onTap;

  const _OrderButton({
    required this.label,
    required this.activo,
    required this.descendente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF2B2B2B).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? const Color(0xFF2B2B2B) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? const Color(0xFF2B2B2B) : Colors.grey[600],
              ),
            ),
            if (activo) ...[
              const SizedBox(width: 4),
              Icon(
                descendente ? Icons.arrow_downward : Icons.arrow_upward,
                size: 14,
                color: const Color(0xFF2B2B2B),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
