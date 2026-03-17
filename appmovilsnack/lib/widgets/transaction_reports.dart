// Archivo: lib/widgets/transaction_reports.dart
// Reportes de Transacciones - Monitoreo de ventas por eventos

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/core/app_theme.dart';
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
      final firestore = FirebaseFirestore.instance;
      const int limitTransacciones = 500;

      // 1) Cargar en paralelo: eventos activos (si aplica), transacciones y todos los eventos
      final bool filtrarSoloActivos = _eventoSeleccionadoId == null;
      final futureTransacciones = _eventoSeleccionadoId != null
          ? firestore
              .collection('transacciones')
              .where('eventoId', isEqualTo: _eventoSeleccionadoId)
              .orderBy('fecha', descending: true)
              .get()
          : firestore
              .collection('transacciones')
              .orderBy('fecha', descending: true)
              .limit(limitTransacciones)
              .get();

      final futureEventos = firestore.collection('eventos').get();

      QuerySnapshot transaccionesSnapshot;
      QuerySnapshot eventosSnapshot;
      Set<String>? eventosActivosIds;

      if (filtrarSoloActivos) {
        final futureActivos = firestore
            .collection('eventos')
            .where('activo', isEqualTo: true)
            .get();
        final results = await Future.wait([
          futureActivos,
          futureTransacciones,
          futureEventos,
        ]);
        eventosActivosIds = (results[0] as QuerySnapshot).docs.map((d) => d.id).toSet();
        transaccionesSnapshot = results[1] as QuerySnapshot;
        eventosSnapshot = results[2] as QuerySnapshot;
      } else {
        final results = await Future.wait([futureTransacciones, futureEventos]);
        transaccionesSnapshot = results[0] as QuerySnapshot;
        eventosSnapshot = results[1] as QuerySnapshot;
      }

      final Map<String, String> eventosMap = {};
      for (var doc in eventosSnapshot.docs) {
        eventosMap[doc.id] = (doc.data() as Map<String, dynamic>?)?['nombre']?.toString() ?? 'Sin evento';
      }

      // 2) Filtrar transacciones y obtener solo los eventoIds que necesitamos para sectores
      final List<QueryDocumentSnapshot> docsFiltrados = [];
      final Set<String> eventoIdsParaSectores = {};
      for (var transDoc in transaccionesSnapshot.docs) {
        final transData = (transDoc.data() as Map<String, dynamic>?) ?? {};
        final eventoId = transData['eventoId']?.toString() ?? '';
        if (eventosActivosIds != null && (eventoId.isEmpty || !eventosActivosIds.contains(eventoId))) {
          continue;
        }
        docsFiltrados.add(transDoc);
        if (eventoId.isNotEmpty) eventoIdsParaSectores.add(eventoId);
      }

      // 3) Cargar sectores solo de esos eventos (en paralelo)
      final Map<String, Map<String, String>> sectoresMap = {};
      if (eventoIdsParaSectores.isNotEmpty) {
        final listaEventoIds = eventoIdsParaSectores.toList();
        final sectorSnapshots = await Future.wait(
          listaEventoIds.map((eventoId) => firestore
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .get()),
        );
        for (var i = 0; i < listaEventoIds.length; i++) {
          final eventoId = listaEventoIds[i];
          sectoresMap[eventoId] = {};
          for (var sectorDoc in sectorSnapshots[i].docs) {
            sectoresMap[eventoId]![sectorDoc.id] =
                (sectorDoc.data() as Map<String, dynamic>?)?['nombre']?.toString() ?? 'Sin sector';
          }
        }
      }

      final List<Map<String, dynamic>> transaccionesData = [];

      for (var transDoc in docsFiltrados) {
        final transData = (transDoc.data() as Map<String, dynamic>?) ?? {};
        final eventoId = transData['eventoId']?.toString() ?? '';
        final sectorId = transData['sectorId']?.toString() ?? '';
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
          'vendedorUid': transData['vendedorUid']?.toString(),
          'vendedorNombre': transData['vendedorNombre']?.toString() ?? 'Sin vendedor',
          'montoTotal': (transData['montoTotal'] as num?)?.toDouble() ?? 0.0,
          'metodoPago': transData['metodoPago']?.toString() ?? 'No especificado',
          'fecha': fechaDateTime,
        });
      }

      // Resolver usernames en paralelo
      final uids = transaccionesData
          .map((t) => t['vendedorUid']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final Map<String, String> uidToUsername = {};
      if (uids.isNotEmpty) {
        final snaps = await Future.wait(
          uids.map((uid) => firestore.collection('usuarios').doc(uid).get()),
        );
        for (var i = 0; i < uids.length; i++) {
          final un = snaps[i].data()?['username']?.toString();
          if (un != null && un.isNotEmpty) uidToUsername[uids[i]] = un;
        }
      }
      for (var t in transaccionesData) {
        final uid = t['vendedorUid']?.toString();
        if (uid != null && uidToUsername.containsKey(uid)) {
          t['vendedorNombre'] = uidToUsername[uid];
        }
      }

      _ordenarTransacciones(transaccionesData);

      if (mounted) {
        setState(() {
          _transaccionesData = transaccionesData;
          _transaccionesFiltrados = transaccionesData;
          _isLoading = false;
        });
      }
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
        backgroundColor: AppColors.surface,
        title: Text(
          'Seleccionar Evento',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryLight,
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
                    'Todos (solo partidos activos)',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Ver transacciones solo de partidos en curso',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos (solo partidos activos)'});
                  },
                );
              }

              final eventoDoc = eventosSnapshot.docs[index - 1];
              final eventoData = eventoDoc.data();
              final eventoNombre = eventoData['nombre']?.toString() ?? 'Sin nombre';
              final bool activo = eventoData['activo'] == true;
              final String estado = activo ? 'Activo' : 'Finalizado';

              return ListTile(
                title: Text(eventoNombre, style: GoogleFonts.poppins()),
                subtitle: Text(
                  estado,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: activo ? Colors.green : Colors.grey,
                    fontWeight: activo ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Reportes de Transacciones',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportesTransacciones,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                            color: AppColors.secondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _cargarReportesTransacciones,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.primaryLight,
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
                                    _eventoSeleccionadoNombre ?? 'Todos (solo partidos activos)',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                                    foregroundColor: AppColors.primaryLight,
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
                                  color: AppColors.primaryLight,
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
                                  color: AppColors.secondary,
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
                            color: AppColors.primaryLight,
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
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ),

                    // Lista de transacciones
                    Expanded(
                      child:                     _transaccionesFiltrados.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: AppColors.secondary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _eventoSeleccionadoId != null
                                          ? 'No hay transacciones para este partido'
                                          : 'No hay transacciones disponibles',
                                      style: GoogleFonts.poppins(
                                        color: AppColors.secondary,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_eventoSeleccionadoId != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Puede que no haya ventas registradas para este partido.',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
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
                                        color: AppColors.accent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.payment,
                                        color: AppColors.accent,
                                        size: 28,
                                      ),
                                    ),
                                    title: Text(
                                      _formatearMonto(monto),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppColors.primaryLight,
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
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$sectorNombre • $vendedorNombre',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.secondary,
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
                                      color: AppColors.secondary,
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
