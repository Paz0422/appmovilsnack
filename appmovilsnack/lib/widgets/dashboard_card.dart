import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';

/// Tarjeta reutilizable para KPIs y métricas del dashboard (tema Fusión).
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool darkText;
  final Color? backgroundColor;
  final Color? borderColor;
  final double elevation;
  final double borderRadius;
  final bool emphasis;
  final String? subtitle;
  final bool compact;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.darkText = false,
    this.backgroundColor,
    this.borderColor,
    this.elevation = 1,
    this.borderRadius = AppRadius.lg,
    this.emphasis = false,
    this.subtitle,
    this.compact = false,
  });

  /// KPI principal (vertical, destacado).
  factory DashboardCard.kpi({
    Key? key,
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return DashboardCard(
      key: key,
      title: title,
      value: value,
      icon: icon,
      subtitle: subtitle,
      iconColor: iconColor ?? AppColors.accent,
      onTap: onTap,
      darkText: true,
      backgroundColor: AppColors.surfaceCard,
      elevation: 1,
      emphasis: true,
    );
  }

  /// Estadística compacta para grillas (borde outline, sin sombra fuerte).
  factory DashboardCard.stat({
    Key? key,
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return DashboardCard(
      key: key,
      title: title,
      value: value,
      icon: icon,
      subtitle: subtitle,
      onTap: onTap,
      iconColor: AppColors.onSurfaceVariant,
      darkText: true,
      backgroundColor: AppColors.surfaceCard,
      borderColor: AppColors.outline,
      elevation: 0,
      compact: true,
    );
  }

  Color get _resolvedIconColor => iconColor ?? AppColors.accent;

  Color get _titleColor => darkText
      ? AppColors.onSurfaceVariant
      : AppColors.onPrimary.withValues(alpha: 0.85);

  Color get _valueColor => darkText ? AppColors.onSurface : AppColors.onPrimary;

  Color get _subtitleColor => darkText
      ? AppColors.onSurfaceVariant.withValues(alpha: 0.9)
      : AppColors.onPrimary.withValues(alpha: 0.75);

  BoxDecoration get _decoration => BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: elevation > 0 ? AppShadows.card : null,
      );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact();
    }
    return _buildVertical();
  }

  Widget _buildCompact() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: _decoration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: _resolvedIconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: _titleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(
                          color: _subtitleColor,
                          fontSize: 10,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: GoogleFonts.poppins(
                          color: _valueColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVertical() {
    if (emphasis) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            decoration: _decoration,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: _resolvedIconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _titleColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _subtitleColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _valueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final valueSize = 22.0;
    const iconSize = 40.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          decoration: _decoration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: _resolvedIconColor),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                  color: _valueColor,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: _subtitleColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
