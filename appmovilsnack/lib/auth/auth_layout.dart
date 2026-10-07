import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';

/// Plantilla de las pantallas de acceso secundarias (registro, recuperar
/// contraseña): cabecera negra con el logo y formulario sobre fondo claro.
class PantallaAcceso extends StatelessWidget {
  const PantallaAcceso({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.children,
  });

  final String titulo;
  final String descripcion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SingleChildScrollView(
        padding: conMargenInferior(context, EdgeInsets.zero),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.negro,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                children: [
                  Image.asset(
                    'assets/imagenes/logo.png',
                    height: 84,
                    excludeFromSemantics: true,
                  ).aparicionRebote(),
                  const SizedBox(height: 14),
                  const FiletMarca(ancho: 56),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        descripcion,
                        style: AppFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tinta,
                          height: 1.35,
                        ),
                      ).entrada(),
                      const SizedBox(height: 24),
                      // Campos y botones entran uno tras otro.
                      for (final (i, hijo) in children.indexed)
                        hijo is SizedBox ? hijo : hijo.entrada(orden: i + 1),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estilo del texto que escribe el usuario en los campos de acceso.
TextStyle get estiloCampoAcceso => AppFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: AppColors.tinta,
);
