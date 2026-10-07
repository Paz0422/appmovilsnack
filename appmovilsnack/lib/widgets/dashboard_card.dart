import 'package:flutter/material.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';

/// Tarjetas del panel de estadísticas del admin.
///
/// - [DashboardCard.kpi]: dato principal sobre degradado dorado, con el texto
///   en azul noche (≥ 9:1).
/// - [DashboardCard.stat]: métrica secundaria sobre pizarra, con un ícono de
///   color ([acento]) para distinguirlas de un vistazo.
///
/// Con [cifra] y [formatearCifra] el valor cuenta hasta su número al
/// aparecer (y [value] queda como texto final y para el lector de pantalla).
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final double? cifra;
  final String Function(double)? formatearCifra;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool _destacada;

  const DashboardCard._({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.subtitle,
    this.cifra,
    this.formatearCifra,
    required bool destacada,
  }) : _destacada = destacada;

  /// KPI principal (total vendido).
  factory DashboardCard.kpi({
    Key? key,
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
    double? cifra,
    String Function(double)? formatearCifra,
  }) => DashboardCard._(
    key: key,
    title: title,
    value: value,
    icon: icon,
    subtitle: subtitle,
    iconColor: iconColor,
    onTap: onTap,
    cifra: cifra,
    formatearCifra: formatearCifra,
    destacada: true,
  );

  /// Métrica para la grilla. [acento] colorea el ícono (dorado si se omite).
  factory DashboardCard.stat({
    Key? key,
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? acento,
    VoidCallback? onTap,
    double? cifra,
    String Function(double)? formatearCifra,
  }) => DashboardCard._(
    key: key,
    title: title,
    value: value,
    icon: icon,
    subtitle: subtitle,
    iconColor: acento,
    onTap: onTap,
    cifra: cifra,
    formatearCifra: formatearCifra,
    destacada: false,
  );

  /// El valor: animado si hay [cifra], si no el texto tal cual.
  Widget _valor(TextStyle style) {
    if (cifra == null || formatearCifra == null) {
      return Text(value, style: style);
    }
    return CifraAnimada(
      valor: cifra!,
      formatear: (v) => v == cifra ? value : formatearCifra!(v),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label: '$title: $value${subtitle == null ? '' : '. $subtitle'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: _destacada ? _buildKpi() : _buildStat(),
        ),
      ),
    );
  }

  Widget _buildKpi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradientes.dorado,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.dorado,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Círculos decorativos, como las tarjetas de las apps de finanzas.
          Positioned(
            right: -40,
            top: -46,
            child: _circulo(130, 0.14),
          ),
          Positioned(
            right: 30,
            bottom: -60,
            child: _circulo(90, 0.10),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.negro.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _valor(
                        AppFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.negro,
                          height: 1.05,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negro.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          subtitle!,
                          style: AppFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.negro,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.negro,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cafe, width: 2.5),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: iconColor ?? AppColors.dorado,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circulo(double tamano, double alfa) => Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alfa),
    ),
  );

  Widget _buildStat() {
    final acento = iconColor ?? AppColors.dorado;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppGradientes.tarjeta,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.separador),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: acento.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 24, color: acento),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _valor(
                    AppFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tinta,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tintaSecundaria,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppColors.tintaSecundaria,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
