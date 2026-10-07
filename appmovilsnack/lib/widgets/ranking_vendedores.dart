// Ranking de vendedores por ventas acumuladas en cierres de turno (año calendario).
import 'package:flutter/material.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/core/precio.dart';

/// Primer año con uso real de la app en ranking (no mostrar años anteriores).
const int _anioInicioRanking = 2026;

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

  List<int> get _aniosDisponibles {
    final actual = DateTime.now().year;
    final inicio = _anioInicioRanking <= actual ? _anioInicioRanking : actual;
    return List.generate(actual - inicio + 1, (i) => actual - i);
  }

  @override
  void initState() {
    super.initState();
    _anioSeleccionado = _aniosDisponibles.first;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lista = await VendedorVentasService.cargarRanking(
        anio: _anioSeleccionado,
      );
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

  @override
  Widget build(BuildContext context) {
    final conVentas = _ranking
        .where(
          (v) => v.montoAnio > 0 || v.cierresAnio > 0 || v.totalHistorico > 0,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Ranking de vendedores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? const CargandoTarjetas()
          : _error != null
          ? ErrorAmable(
              titulo: 'No pudimos cargar el ranking',
              detalle: 'Error: $_error',
              onReintentar: _cargar,
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: conMargenInferior(context, const EdgeInsets.all(16)),
                children: [
                  Row(
                    children: [
                      Text(
                        'Año',
                        style: AppFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_aniosDisponibles.length == 1)
                        Text(
                          '$_anioSeleccionado',
                          style: AppFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        )
                      else
                        DropdownButton<int>(
                          value: _anioSeleccionado,
                          items: _aniosDisponibles
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                ),
                              )
                              .toList(),
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
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (conVentas.isNotEmpty) ...[
                    TarjetaGrafico(
                      titulo: 'Podio $_anioSeleccionado',
                      subtitulo: 'Monto vendido en cierres de turno',
                      child: RankingBarras(
                        formatear: formatearPesos,
                        items: [
                          for (final v in conVentas.take(5))
                            (
                              nombre: v.nombre,
                              detalle:
                                  '${v.cierresAnio} cierre${v.cierresAnio == 1 ? '' : 's'}',
                              monto: v.montoAnio,
                            ),
                        ],
                      ),
                    ).entrada(),
                    const SizedBox(height: 20),
                  ],
                  if (conVentas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: EstadoVacio(
                        titulo: 'Sin cierres registrados en $_anioSeleccionado',
                      ),
                    )
                  else
                    ...conVentas.asMap().entries.map((e) {
                      final pos = e.key + 1;
                      final v = e.value;
                      // Oro, plata y bronce (café) para los tres primeros.
                      final podio = pos <= 3;
                      final color = podio
                          ? AppColors.podio[pos - 1]
                          : AppColors.tintaSecundaria;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          side: BorderSide(
                            color: podio
                                ? color.withValues(alpha: 0.7)
                                : AppColors.separador,
                            width: podio ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.18),
                            child: pos == 1
                                ? Icon(
                                    Icons.emoji_events_rounded,
                                    color: color,
                                  )
                                : Text(
                                    '$pos',
                                    style: AppFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                          ),
                          title: Text(
                            v.nombre,
                            style: AppFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${v.cierresAnio} cierre${v.cierresAnio == 1 ? '' : 's'} · '
                            '${v.unidadesAnio} u.',
                            style: AppFonts.inter(fontSize: 14),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatearPesos(v.montoAnio),
                                style: AppFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              if (v.totalHistorico > v.montoAnio)
                                Text(
                                  'Hist. ${formatearPesos(v.totalHistorico)}',
                                  style: AppFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).entradaEnLista(e.key + 1);
                    }),
                ],
              ),
            ),
    );
  }
}
