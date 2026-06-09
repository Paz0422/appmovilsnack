import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/admin_bandejeo_service.dart';

class ReporteBandejeoAdmin extends StatefulWidget {
  const ReporteBandejeoAdmin({super.key});

  @override
  State<ReporteBandejeoAdmin> createState() => _ReporteBandejeoAdminState();
}

class _ReporteBandejeoAdminState extends State<ReporteBandejeoAdmin> {
  List<MapEntry<String, String>> _eventos = [];
  String? _eventoSeleccionadoId;
  List<AdminBandejeoSectorResumen> _sectores = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final eventos = await AdminBandejeoService.listarEventos();
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        if (_eventoSeleccionadoId == null && eventos.length == 1) {
          _eventoSeleccionadoId = eventos.first.key;
        }
      });
      await _cargarSectores();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cargarSectores() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final sectores = await AdminBandejeoService.cargarPorEvento(
        _eventoSeleccionadoId,
      );
      if (!mounted) return;
      setState(() {
        _sectores = sectores;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  String _fmt(double n) => '\$${n.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Bandejeo por sector',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFiltroEvento(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _cargarSectores,
              child: _buildContenido(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroEvento() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.accent.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista informativa del bandejeo en cada sector: bandejeros, '
            'rondas y dinero en calle.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.secondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _eventoSeleccionadoId,
            decoration: InputDecoration(
              labelText: 'Evento',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos los eventos activos'),
              ),
              ..._eventos.map(
                (e) => DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text(e.value),
                ),
              ),
            ],
            onChanged: _cargando
                ? null
                : (v) {
                    setState(() => _eventoSeleccionadoId = v);
                    _cargarSectores();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            'Error al cargar: $_error',
            style: GoogleFonts.poppins(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _cargarSectores,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (_sectores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 56,
            color: AppColors.secondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay bandejeo registrado',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando los sectores agreguen bandejeros y rondas, '
            'aparecerán aquí.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.secondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _sectores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _SectorBandejeoCard(
        resumen: _sectores[index],
        fmt: _fmt,
        mostrarEvento: _eventoSeleccionadoId == null,
      ),
    );
  }
}

class _SectorBandejeoCard extends StatelessWidget {
  final AdminBandejeoSectorResumen resumen;
  final String Function(double) fmt;
  final bool mostrarEvento;

  const _SectorBandejeoCard({
    required this.resumen,
    required this.fmt,
    required this.mostrarEvento,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            child: Icon(Icons.storefront, color: AppColors.secondary),
          ),
          title: Text(
            resumen.sectorNombre,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryLight,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarEvento) ...[
                const SizedBox(height: 2),
                Text(
                  resumen.eventoNombre,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.secondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ChipInfo(
                    '${resumen.totalBandejeros} bandejero${resumen.totalBandejeros == 1 ? '' : 's'}',
                  ),
                  _ChipInfo('${resumen.rondasRendidas} ronda${resumen.rondasRendidas == 1 ? '' : 's'}'),
                  if (resumen.rondasEnCurso > 0)
                    _ChipInfo(
                      '${resumen.rondasEnCurso} en curso',
                      color: Colors.orange,
                    ),
                ],
              ),
            ],
          ),
          children: [
            _ResumenFila(
              icon: Icons.payments_outlined,
              label: 'Vendido (rondas rendidas)',
              valor: fmt(resumen.totalVendido),
            ),
            _ResumenFila(
              icon: Icons.shopping_basket_outlined,
              label: 'Valor en bandeja (rondas activas)',
              valor: fmt(resumen.valorEnBandeja),
            ),
            _ResumenFila(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Caja vuelto (bandejeros en turno)',
              valor: fmt(resumen.cajaVueltoActiva),
            ),
            _ResumenFila(
              icon: Icons.trending_up,
              label: 'Estimado en calle',
              valor: fmt(resumen.efectivoEstimadoSector),
              destacado: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Bandejeros',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 6),
            ...resumen.bandejeros.map(
              (b) => _BandejeroTile(bandejero: b, fmt: fmt),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final String texto;
  final Color? color;

  const _ChipInfo(this.texto, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.secondary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color ?? AppColors.secondary,
        ),
      ),
    );
  }
}

class _ResumenFila extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final bool destacado;

  const _ResumenFila({
    required this.icon,
    required this.label,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.secondary,
              ),
            ),
          ),
          Text(
            valor,
            style: GoogleFonts.poppins(
              fontSize: destacado ? 15 : 13,
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              color: destacado ? AppColors.success : AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandejeroTile extends StatelessWidget {
  final AdminBandejeroResumen bandejero;
  final String Function(double) fmt;

  const _BandejeroTile({
    required this.bandejero,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final estado = bandejero.cerrado
        ? 'Cerrado'
        : bandejero.tieneRondaEnCurso
            ? 'Ronda en curso'
            : bandejero.rondasRendidas > 0
                ? 'Entre rondas'
                : 'Sin rondas';

    final estadoColor = bandejero.cerrado
        ? Colors.grey
        : bandejero.tieneRondaEnCurso
            ? Colors.orange
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bandejero.nombre,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estado,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: estadoColor == Colors.grey
                        ? Colors.grey[700]
                        : estadoColor == Colors.orange
                            ? Colors.orange[900]
                            : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${bandejero.rondasRendidas} ronda${bandejero.rondasRendidas == 1 ? '' : 's'} rendida${bandejero.rondasRendidas == 1 ? '' : 's'} · '
            'Vendido: ${fmt(bandejero.totalVendido)}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.secondary,
            ),
          ),
          if (!bandejero.cerrado) ...[
            Text(
              'En bandeja: ${fmt(bandejero.valorEnBandeja)} · '
              'Caja vuelto: ${fmt(bandejero.cajaVuelto)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.secondary,
              ),
            ),
            if (bandejero.tieneRondaEnCurso || bandejero.cajaVuelto > 0)
              Text(
                'Estimado en calle: ${fmt(bandejero.efectivoEstimadoEnCalles)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
          ],
          if (bandejero.cerrado && bandejero.totalARecibirCierre != null)
            Text(
              'Total recibido al cierre: ${fmt(bandejero.totalARecibirCierre!)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          if (bandejero.cerrado &&
              bandejero.comisionAlCierre != null &&
              bandejero.porcentajeComision != null)
            Text(
              'Comisión al cierre: ${fmt(bandejero.comisionAlCierre!)} '
              '(${bandejero.porcentajeComision!.toStringAsFixed(bandejero.porcentajeComision!.roundToDouble() == bandejero.porcentajeComision! ? 0 : 1)}%)',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.secondary,
              ),
            )
          else if (!bandejero.cerrado)
            Text(
              'Comisión: se ingresa al cerrar el bandejeo',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.secondary,
              ),
            ),
        ],
      ),
    );
  }
}
