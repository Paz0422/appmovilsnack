// Tema "Fusión – Healthy Snacks & Coffee".
//
// Tema OSCURO moderno: fondo azul noche, tarjetas azul pizarra y el dorado de
// la marca como acento (botones principales, cifras destacadas y gráficos).
//
// Contraste (WCAG, ver test/core/contraste_test.dart): el texto claro y el
// dorado se leen sobre fondo y tarjetas (≥ 7:1); sobre dorado o sobre los
// colores de estado (éxito, error, aviso) el texto va en azul noche [negro].
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front_appsnack/core/tipografia.dart';

/// Paleta de la marca y del tema.
class AppColors {
  AppColors._();

  // --- Marca ---
  /// Azul noche profundo: zonas de marca y texto sobre dorado o estados.
  /// (Se llama "negro" por compatibilidad: cumple el mismo rol.)
  static const Color negro = Color(0xFF081221);
  static const Color dorado = Color(0xFFEDC661);
  static const Color doradoOscuro = Color(0xFFD4A63E);
  static const Color cafe = Color(0xFFC79A5B);

  // --- Superficies ---
  static const Color fondo = Color(0xFF0E1A2B);
  static const Color tarjeta = Color(0xFF182840);

  /// Campos de texto y elementos sobre una tarjeta.
  static const Color tarjetaAlta = Color(0xFF22354F);

  /// Texto principal (claro).
  static const Color tinta = Color(0xFFF3F6FB);

  /// Texto secundario (7,4:1 sobre tarjeta).
  static const Color tintaSecundaria = Color(0xFFA9B8CE);

  /// Resaltado y selección (fondo dorado apagado, texto claro).
  static const Color doradoSuave = Color(0xFF3A3421);

  /// Contorno de campos y casillas (≥ 3:1 sobre tarjeta).
  static const Color bordeCampo = Color(0xFF6A80A0);

  /// Separadores y bordes de tarjetas (solo decorativo).
  static const Color separador = Color(0xFF2A3D5A);

  /// Mensajes emergentes.
  static const Color grafito = Color(0xFF22354F);

  // --- Estados (claros: se leen como texto sobre oscuro; como relleno,
  // llevan texto [negro]) ---
  static const Color exito = Color(0xFF4CD38A);
  static const Color exitoSuave = Color(0xFF173B2E);
  static const Color errorSuave = Color(0xFF3D1E26);
  static const Color aviso = Color(0xFFFFB547);
  static const Color avisoTexto = Color(0xFFFFD48A);
  static const Color avisoSuave = Color(0xFF3A2E14);

  /// Fondos de mensajes emergentes (texto claro encima, ≥ 4,5:1).
  static const Color exitoFuerte = Color(0xFF1E7D4E);
  static const Color errorFuerte = Color(0xFFB23A4A);
  static const Color avisoFuerte = Color(0xFF8F5400);

  // --- Gráficos ---
  static const Color cian = Color(0xFF4CC9F0);
  static const Color coral = Color(0xFFFF8A80);
  static const Color violeta = Color(0xFFA99BFF);

  /// Serie de colores para gráficos (el primero es el de la marca).
  static const List<Color> grafico = [dorado, cian, coral, violeta, exito];

  // --- Nombres usados en toda la app (mismos roles, valores nuevos) ---
  /// Zonas de marca (cabeceras).
  static const Color primary = negro;

  /// Texto principal. (Históricamente "oscuro"; ahora es el texto claro.)
  static const Color primaryLight = tinta;

  /// Dorado: acento principal.
  static const Color accent = dorado;
  static const Color accentLight = Color(0xFFF3D98E);

  /// Texto secundario.
  static const Color secondary = tintaSecundaria;
  static const Color surface = fondo;
  static const Color surfaceCard = tarjeta;
  static const Color error = Color(0xFFFF7070);
  static const Color success = exito;
  static const Color onPrimary = tinta;
  static const Color onSurface = tinta;
  static const Color onSurfaceVariant = tintaSecundaria;
  static const Color outline = separador;
}

/// Degradados de la marca.
class AppGradientes {
  AppGradientes._();

  /// Tarjeta destacada y botones principales.
  static const LinearGradient dorado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7DB86), AppColors.doradoOscuro],
  );

  /// Totales de pérdida (rojo oscuro: el texto blanco se lee sobre él).
  static const LinearGradient perdida = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB23A4A), Color(0xFF6E2030)],
  );

  /// Tarjetas con algo de profundidad.
  static const LinearGradient tarjeta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3150), Color(0xFF16253B)],
  );
}

/// Radios consistentes.
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

/// Tamaños mínimos de toque (dedo, de pie, con una mano).
class AppTamanos {
  AppTamanos._();

  /// Botones principales.
  static const double boton = 56;

  /// Mínimo de cualquier elemento tocable.
  static const double toque = 48;
}

/// Sombras suaves para profundidad.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Resplandor dorado de la tarjeta destacada.
  static List<BoxShadow> dorado = [
    BoxShadow(
      color: AppColors.dorado.withValues(alpha: 0.14),
      blurRadius: 22,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Tema de la aplicación.
class AppTheme {
  AppTheme._();

  static ThemeData get tema {
    final textTheme = _buildTextTheme();
    final formaBoton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final textoBoton = AppFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w700,
    );
    const tamanoBoton = Size(64, AppTamanos.boton);

    OutlineInputBorder bordeCampo(Color color, [double ancho = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.texto,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.dorado,
        onPrimary: AppColors.negro,
        primaryContainer: AppColors.doradoSuave,
        onPrimaryContainer: AppColors.tinta,
        secondary: AppColors.cian,
        onSecondary: AppColors.negro,
        tertiary: AppColors.dorado,
        onTertiary: AppColors.negro,
        surface: AppColors.fondo,
        onSurface: AppColors.tinta,
        onSurfaceVariant: AppColors.tintaSecundaria,
        surfaceContainerLowest: AppColors.fondo,
        surfaceContainerLow: AppColors.tarjeta,
        surfaceContainer: AppColors.tarjeta,
        surfaceContainerHigh: AppColors.tarjetaAlta,
        surfaceContainerHighest: AppColors.tarjetaAlta,
        outline: AppColors.bordeCampo,
        outlineVariant: AppColors.separador,
        error: AppColors.error,
        onError: AppColors.negro,
        errorContainer: AppColors.errorSuave,
        onErrorContainer: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.fondo,
      canvasColor: AppColors.fondo,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // Cabecera integrada al fondo (sin franja), título claro e íconos dorados.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        backgroundColor: AppColors.fondo,
        foregroundColor: AppColors.tinta,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.fondo,
        ),
        titleTextStyle: AppFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.tinta,
        ),
        iconTheme: const IconThemeData(color: AppColors.dorado, size: 26),
        actionsIconTheme: const IconThemeData(
          color: AppColors.dorado,
          size: 26,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.separador),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.tarjetaAlta,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: bordeCampo(AppColors.separador),
        enabledBorder: bordeCampo(AppColors.separador),
        focusedBorder: bordeCampo(AppColors.dorado, 2),
        errorBorder: bordeCampo(AppColors.error),
        focusedErrorBorder: bordeCampo(AppColors.error, 2),
        labelStyle: AppFonts.inter(
          color: AppColors.tintaSecundaria,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: AppFonts.inter(
          color: AppColors.dorado,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: AppFonts.inter(
          color: AppColors.tintaSecundaria,
          fontSize: 16,
        ),
        helperStyle: AppFonts.inter(
          color: AppColors.tintaSecundaria,
          fontSize: 14,
        ),
        errorStyle: AppFonts.inter(
          color: AppColors.error,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.tintaSecundaria,
        suffixIconColor: AppColors.tintaSecundaria,
      ),
      // Principal: dorado con texto azul noche.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.dorado,
          foregroundColor: AppColors.negro,
          disabledBackgroundColor: AppColors.tarjetaAlta,
          disabledForegroundColor: AppColors.tintaSecundaria,
          minimumSize: tamanoBoton,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: formaBoton,
          textStyle: textoBoton,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.dorado,
          foregroundColor: AppColors.negro,
          disabledBackgroundColor: AppColors.tarjetaAlta,
          disabledForegroundColor: AppColors.tintaSecundaria,
          minimumSize: tamanoBoton,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: formaBoton,
          textStyle: textoBoton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dorado,
          backgroundColor: Colors.transparent,
          minimumSize: tamanoBoton,
          side: const BorderSide(color: AppColors.dorado, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: formaBoton,
          textStyle: textoBoton,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dorado,
          minimumSize: const Size(AppTamanos.toque, AppTamanos.toque),
          textStyle: AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppTamanos.toque, AppTamanos.toque),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.dorado,
        foregroundColor: AppColors.negro,
        elevation: 6,
        extendedTextStyle: AppFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        extendedSizeConstraints: const BoxConstraints.tightFor(
          height: AppTamanos.boton,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: AppColors.grafito,
        actionTextColor: AppColors.dorado,
        contentTextStyle: AppFonts.inter(
          color: AppColors.tinta,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.tinta,
        ),
        contentTextStyle: AppFonts.inter(
          fontSize: 16,
          color: AppColors.tinta,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.tarjetaAlta,
        surfaceTintColor: Colors.transparent,
        textStyle: AppFonts.inter(fontSize: 16, color: AppColors.tinta),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.tarjetaAlta),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.dorado,
        unselectedLabelColor: AppColors.tintaSecundaria,
        indicatorColor: AppColors.dorado,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.separador,
        labelStyle: AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
        unselectedLabelStyle: AppFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tarjeta,
        selectedColor: AppColors.doradoSuave,
        checkmarkColor: AppColors.dorado,
        side: const BorderSide(color: AppColors.separador),
        labelStyle: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.tinta,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: AppColors.dorado,
        textColor: AppColors.tinta,
        titleTextStyle: AppFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.tinta,
        ),
        subtitleTextStyle: AppFonts.inter(
          fontSize: 14,
          color: AppColors.tintaSecundaria,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.dorado,
        linearTrackColor: AppColors.separador,
        refreshBackgroundColor: AppColors.tarjeta,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.dorado : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.negro),
        side: const BorderSide(color: AppColors.bordeCampo, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.dorado
              : AppColors.bordeCampo,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.negro
              : AppColors.tintaSecundaria,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.dorado
              : AppColors.tarjetaAlta,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.dorado
              : AppColors.bordeCampo,
        ),
      ),
      // Navegación principal: barra pizarra con la sección activa en dorado.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
        height: 76,
        indicatorColor: AppColors.dorado,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected)
                ? AppColors.negro
                : AppColors.tintaSecundaria,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppFonts.inter(
            fontSize: 14,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? AppColors.dorado
                : AppColors.tintaSecundaria,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.tarjeta,
        indicatorColor: AppColors.dorado,
        labelType: NavigationRailLabelType.all,
        minWidth: 96,
        selectedIconTheme: const IconThemeData(
          color: AppColors.negro,
          size: 26,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.tintaSecundaria,
          size: 26,
        ),
        selectedLabelTextStyle: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.dorado,
        ),
        unselectedLabelTextStyle: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.tintaSecundaria,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.separador,
        thickness: 1,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.dorado,
        collapsedIconColor: AppColors.tintaSecundaria,
        textColor: AppColors.tinta,
        collapsedTextColor: AppColors.tinta,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.tarjeta,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.tarjeta,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: AppFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.tinta,
        letterSpacing: -0.5,
      ),
      displayMedium: AppFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.tinta,
      ),
      headlineMedium: AppFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.tinta,
      ),
      titleLarge: AppFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.tinta,
      ),
      titleMedium: AppFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.tinta,
      ),
      bodyLarge: AppFonts.inter(
        fontSize: 16,
        color: AppColors.tinta,
        height: 1.4,
      ),
      bodyMedium: AppFonts.inter(
        fontSize: 16,
        color: AppColors.tinta,
        height: 1.4,
      ),
      bodySmall: AppFonts.inter(fontSize: 14, color: AppColors.tintaSecundaria),
      labelLarge: AppFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.tinta,
      ),
    );
  }
}
