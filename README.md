# Fusión Snacks — app móvil

Aplicación Flutter para gestión de ventas, stock y eventos en estadio. El código del proyecto está en **`appmovilsnack/`**.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.8.1
- Android Studio / VS Code con extensiones Flutter y Dart
- Proyecto Firebase `snack-estadio` configurado en tu máquina

## Ejecutar la app

Siempre trabajá desde la carpeta del proyecto Flutter:

```bash
cd appmovilsnack
flutter pub get
flutter run
```

Para compilar release Android:

```bash
cd appmovilsnack
flutter build apk --release
```

## Configuración Firebase (por desarrollador)

Estos archivos **no están en git** (ver `.gitignore`). Cada desarrollador debe generarlos o copiarlos de forma segura:

| Archivo | Ubicación |
|---------|-----------|
| `firebase_options.dart` | `appmovilsnack/lib/firebase_options.dart` |
| `google-services.json` | `appmovilsnack/android/app/google-services.json` |

Con FlutterFire CLI, desde `appmovilsnack/`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

## Firestore

- Reglas: `appmovilsnack/firestore.rules`
- Índices: `appmovilsnack/firestore.indexes.json`

Desplegar reglas (con Firebase CLI en la raíz del repo o en `appmovilsnack/` según tu `firebase.json`):

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Estructura

```
appmovilsnack/
├── lib/           # Código Dart (auth, screens, widgets, services)
├── android/       # Build Android
├── assets/        # Imágenes (logo, etc.)
├── fonts/         # Tipografías
└── pubspec.yaml   # Dependencias
```
