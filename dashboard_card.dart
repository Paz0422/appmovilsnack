import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Gradient? gradient;
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
    required this.color,
    this.onTap,
    this.gradient,
    this.darkText = false,
    this.backgroundColor,
    this.borderColor,
    this.elevation = 6,
    this.borderRadius = 18,
    this.emphasis = false,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? Colors.black87 : Colors.white;
    final subTextColor = darkText ? Colors.black54 : Colors.white70;

    final decoration = BoxDecoration(
      gradient: gradient,
      color: gradient == null ? (backgroundColor ?? Colors.white) : null,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null ? Border.all(color: borderColor!) : null,
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );

    // === Layout compacto (horizontal) para tiles finitas ===
    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Container(
            decoration: decoration,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: gradient != null
                      ? Colors.black87
                      : (borderColor != null ? Colors.black54 : color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(color: subTextColor, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // === Layout normal (vertical) para KPIs y “Total Vendido” ===
    final valueStyle = TextStyle(
      fontSize: emphasis ? 28 : 22,
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: 0.2,
    );

    final titleStyle = TextStyle(
      fontSize: emphasis ? 15 : 14,
      fontWeight: FontWeight.w600,
      color: subTextColor,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: emphasis ? 44 : 40,
                color: gradient != null ? Colors.black87 : color,
              ),
              const SizedBox(height: 12),
              Text(value, style: valueStyle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(title, style: titleStyle, textAlign: TextAlign.center),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12.5, color: subTextColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
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
