// Ranking de vendedores por ventas acumuladas en cierres de turno (año calendario).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';

class RankingVendedores extends StatefulWidget {
  const RankingVendedores({super.key});

  @override
  State<RankingVendedores> createState() => _RankingVendedoresState();
}

class _RankingVendedoresState extends State<RankingVendedores> {
  bool _loading = true;
  String? _error;
  List<RankingVendedor> _ranking = [];
  late int _anioSeleccionado;

  @override
  void initState() {
    super.initState();
    _anioSeleccionado = DateTime.now().year;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lista =
          await VendedorVentasService.cargarRanking(anio: _anioSeleccionado);
      if (!mounted) return;
      setState(() {
        _ranking = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtMonto(num v) {
    final s = v.round().abs().toString();
    final buf = StringBuffer(v < 0 ? '-' : '');
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final resto = s.length - i - 1;
      if (resto > 0 && resto % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final conVentas = _ranking
        .where((v) => v.montoAnio > 0 || v.cierresAnio > 0 || v.totalHistorico > 0)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Ranking de vendedores',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: GoogleFonts.poppins(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Text(
                            'Año',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _anioSeleccionado,
                            items: List.generate(5, (i) {
                              final y = DateTime.now().year - i;
                              return DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              );
                            }),
                            onChanged: (y) {
                              if (y == null) return;
                              setState(() => _anioSeleccionado = y);
                              _cargar();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Suma el monto vendido en cada cierre de turno del punto '
                        '(inventario inicial vs final). No incluye bandejeo.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (conVentas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Sin cierres registrados en $_anioSeleccionado',
                              style: GoogleFonts.poppins(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ...conVentas.asMap().entries.map((e) {
                          final pos = e.key + 1;
                          final v = e.value;
                          final esTop = pos == 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: esTop ? 3 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: esTop
                                  ? BorderSide(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.6),
                                      width: 2,
                                    )
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esTop
                                    ? AppColors.accent
                                    : AppColors.accent
                                        .withValues(alpha: 0.25),
                                child: Text(
                                  '$pos',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: esTop
                                        ? AppColors.primaryLight
                                        : AppColors.secondary,
                                  ),
                                ),
                              ),
                              title: Text(
                                v.nombre,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${v.cierresAnio} cierre${v.cierresAnio == 1 ? '' : 's'} · '
                                '${v.unidadesAnio} u.',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${_fmtMonto(v.montoAnio)}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                  if (v.totalHistorico > v.montoAnio)
                                    Text(
                                      'Hist. \$${_fmtMonto(v.totalHistorico)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
