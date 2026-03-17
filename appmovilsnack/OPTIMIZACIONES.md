# Optimizaciones aplicadas al proyecto

## 1. Tema central (`lib/core/app_theme.dart`)

- **Paleta unificada:** `AppColors` (primary, accent, secondary, surface, etc.) con los valores que ya usaba la app (0xFFDABF41, 0xFF2B2B2B, 0xFF6B4D2F, 0xFFFDFBF7).
- **Radios y sombras:** `AppRadius` (sm, md, lg, xl) y `AppShadows.card` para mantener el mismo criterio visual en cards y contenedores.

**Uso:** En cualquier archivo, `import 'package:front_appsnack/core/app_theme.dart';` y usar `AppColors.primaryLight`, `AppRadius.lg`, etc.

---

## 2. Helpers de Firestore (`lib/services/firestore_helpers.dart`)

- **Consultas reutilizables:** En lugar de repetir `FirebaseFirestore.instance.collection('eventos')...` en muchos archivos, se centralizó en:
  - `FirestoreHelpers.getEventosActivos()` / `getEventos()`
  - `FirestoreHelpers.streamEventosActivos()`
  - `FirestoreHelpers.getSectores(eventoId)` / `streamSectores(eventoId)`
  - `FirestoreHelpers.getSector(eventoId, sectorId)`

**Archivos que ya usan estos helpers:** `estadio_selection.dart`, `home_vendedor.dart`, `reporte_mermas.dart`.

**Próximo paso:** Ir reemplazando en el resto de pantallas (stock_reports, transaction_reports, asignacion_stock, traspaso_stock, etc.) las llamadas directas a Firestore por estos métodos donde aplique.

---

## 3. Unificación de colores

Se reemplazaron las definiciones locales de `primaryColor`, `accentColor`, `secondaryColor`, `backgroundColor` por `AppColors` en:

- `reporte_mermas.dart`
- `transaction_reports.dart`
- `ventas_por_categoria.dart`
- `resumen_cierre_turno.dart`
- `estadio_selection.dart` (ya usaba el tema)

**Archivos que aún tienen colores locales** (se pueden migrar igual):  
`home_admin.dart`, `home_vendedor.dart`, `panel_ventas.dart`, `gestion_stock.dart`, `bandejeo_flow.dart`, `eventos_management.dart`, `registro_merma.dart`, `stock_reports.dart`, `dashboard_ventas_vendedores.dart`, `asignacion_stock.dart`, `traspaso_stock.dart`, `gestion_categorias.dart`, `gestion_roles_usuarios.dart`, `asignacion_personal.dart`, `inventory_management.dart`, `stock_screen.dart`, `gestion_screen.dart`, `register_screen.dart`, `reset_password_screen.dart`.

---

## 4. Recomendaciones futuras

- **Rendimiento:** En listas largas (por ejemplo detalle de categorías en ventas_por_categoria), usar `ListView.builder` en lugar de `ListView(children: list.map(...).toList())` para construir solo los ítems visibles.
- **Const:** Activar la regla `prefer_const_constructors` y corregir los avisos del linter para reducir reconstrucciones innecesarias.
- **Widgets grandes:** En pantallas con `build` muy largo (home_admin, panel_ventas, bandejeo_flow, eventos_management, gestion_stock), extraer bloques a widgets privados (por ejemplo `_HeaderCard`, `_StatsRow`) para mejorar legibilidad y mantenimiento.
- **InputDecoration / ElevatedButton:** El tema en `app_theme.dart` ya define `inputDecorationTheme` y `elevatedButtonTheme`. Donde se use `_buildInputDecoration` o `ElevatedButton.styleFrom(...)` repetido, se puede simplificar usando `Theme.of(context).inputDecorationTheme` o sin sobrescribir estilo en el botón.

---

## Resumen

- Un solo lugar para colores y forma de cards (`app_theme.dart`).
- Un solo lugar para lecturas de eventos y sectores (`firestore_helpers.dart`).
- Varias pantallas ya usan tema y helpers; el resto se puede migrar de forma gradual siguiendo el mismo patrón.
