# Escrituras a Firestore por rol

Base de `firestore.rules`. Si cambia una escritura en `lib/`, actualizar esta tabla, las reglas y `firestore-tests/rules.test.js`.

Pantallas de admin: `home_admin.dart` → `inventory_management`, `gestion_categorias`, `asignacion_personal`, `eventos_management`, reportes (solo lectura).
Pantallas de vendedor: `estadio_selection` → `home_vendedor` → `gestion_stock`, `registro_merma`, `traspaso_stock`, `confirmacion_traspasos`, `bandejeo_flow`, `resumen_cierre_turno`. El admin también puede entrar al flujo de vendedor (`fromAdmin`).

## Configuración

| Ruta | Operación | Quién | Dónde |
|---|---|---|---|
| `usernames/{username}` | get **sin sesión** para obtener el email antes del `signIn` | cualquiera (login) | `auth_manager.dart` `iniciarSesion` |
| `usuarios/{uid}` + `usernames/{username}` | create en un batch (`usernames` solo con `{ email }`, id = username en minúsculas y sin espacios) | propio usuario al registrarse | `register_screen.dart` `_registerUser` |
| `usuarios/{uid}` | set merge `ventasAcumuladas`, `totalvendido`, `itemsvendidos` | vendedor, sobre su propio perfil | `vendedor_ventas_service.dart:103` |
| `usuarios/{uid}/cierres_contabilizados/{cierreId}` | read + create (en transacción) | vendedor, sobre su propio perfil | `vendedor_ventas_service.dart:66,91` |
| `usuarios/{uid}` | update solo `rol` (`admin` / `vendedor`), nunca el propio perfil | admin | `roles_service.dart` `cambiarRol` (desde `gestion_roles_usuarios.dart`) |
| `productos/{id}` | add / update / delete | admin | `inventory_management.dart:251,253,354` |
| `categorias/{id}` | add / delete | admin | `gestion_categorias.dart:172,238` |
| `categorias/{id}` | add de las categorías por defecto si la colección está vacía | **cualquiera** que llame a `cargarCategoriasFirestore()` (también vendedores) | `categorias_producto.dart:80` |
| `empleados/{id}` | add / update / delete | admin | `asignacion_personal.dart:265,279,349` |
| `eventos/{id}` | create (batch con sectores), update `nombre`/`activo`, delete | admin | `eventos_management.dart:147,652,770` |
| `eventos/{id}/sectores/{id}` | create, update `nombre`, delete | admin | `eventos_management.dart:160,183,191,1220,1347` |
| `eventos/{id}/sectores/{id}` | update `turnoCerrado: false`, borra `turnoCerradoAt` (reabrir; ya no reinicia `stockInicialIngresado`) | admin | `eventos_management.dart` `_reabrirSector` |
| `sectores/{id}/stock/{productoId}` + `eventos/{id}/movimientos/{id}` | `cantidad: increment(n)` y registro `tipo: 'reposicion'` en la misma transacción | admin | `stock_service.dart` `agregarStock` (desde `agregar_stock.dart`) |

## Operación del vendedor

| Ruta | Operación | Dónde |
|---|---|---|
| `sectores/{id}` | set merge `borradorStockInicial`, `stockInicialIngresado: true` | `gestion_stock.dart:150,156,514` |
| `sectores/{id}` | set merge `borradorCierreTurno` (incluye `stockAlIniciar`) | `resumen_cierre_turno.dart` `_guardarBorradorCierre` |
| `sectores/{id}` | set merge `ultimoCierre`, `turnoCerrado: true`, `turnoCerradoAt`, `totalVendido` (increment), `vendedoresasignados`, borra `borradorCierreTurno` (en transacción) | `cierre_turno_service.dart` `cerrarTurno` |
| `sectores/{id}/stock/{productoId}` | set en batch (stock inicial; ya no borra productos) | `gestion_stock.dart` `_persistirStock` |
| `sectores/{id}/stock/{productoId}` | update `cantidad`, `cantidadFinal` (cierre, en transacción que antes compara con el stock al iniciar el conteo) | `cierre_turno_service.dart` `cerrarTurno` |
| `sectores/{id}/cierres/{cierreId}` | create con los datos del cierre, en la misma transacción (historial: `ultimoCierre` se sobrescribe si el sector se reabre) | `cierre_turno_service.dart` `cerrarTurno` |
| `sectores/{id}/stock/{productoId}` | update / set merge `cantidad` (bandeja, rendición) | `bandejeo_flow.dart:851,856,1464` |
| `sectores/{id}/stock/{productoId}` | update `cantidad` (merma) | `registro_merma.dart:1055` |
| `sectores/{origen}/stock/{productoId}` | update `cantidad` al enviar | `traspaso_service.dart` `enviar` (desde `traspaso_stock.dart`) |
| `sectores/{destino y origen}/stock/{productoId}` | update / set al confirmar (suma recibido, devuelve diferencia al origen) | `traspaso_service.dart` `confirmarRecepcion` (desde `confirmacion_traspasos.dart`) |
| `sectores/{id}/mermas/{id}` | create | `registro_merma.dart:1062` |
| `sectores/{destino}/traspasos_entrantes/{id}` | create `estado: 'pendiente'` | `traspaso_service.dart` `enviar` |
| `sectores/{origen}/traspasos_salientes/{id}` | create `estado: 'pendiente'` | `traspaso_service.dart` `enviar` |
| `traspasos_entrantes` / `traspasos_salientes` | update `estado: 'confirmado'`, `cantidadRecibida`, `cantidadDiferencia`, `confirmadoAt`, `comentarioDiferencia`; si falta la saliente se crea ya confirmada | `traspaso_service.dart` `confirmarRecepcion` |
| `sectores/{id}/bandejeros/{id}` | create; set merge `cajaVuelto`, `ultimaRondaRendida`, `bandejeoCerrado`, `cierreResumen`… | `bandejeo_flow.dart:2156,1003,1537,1391` |
| `eventos/{id}/discrepancias/{traspasoId}` | create `tipo: 'faltante_traspaso'`, `estado: 'pendiente'` con origen, destino, producto, enviado, recibido, diferencia, vendedor y fecha, cuando el origen del traspaso ya cerró su turno | `traspaso_service.dart` `confirmarRecepcion` |
| `eventos/{id}/discrepancias/{cierreId}_{productoId}` | create `tipo: 'sobrante_conteo'`, `estado: 'pendiente'` con sector, producto, stock del sistema, contado, diferencia, vendedor y fecha, en la transacción del cierre | `cierre_turno_service.dart` `cerrarTurno` |
| `bandejeros/{id}/rondas/{id}` | set merge (guardar ronda, rendir) | `bandejeo_flow.dart:864,1510` |
| `transacciones/{id}` | create (rendición de bandejeo) | `bandejeo_flow.dart:1476` |

Los traspasos escriben stock de **otro** sector, y no existe en Firestore una asignación vendedor↔sector ligada al uid, así que las reglas no pueden limitar a un vendedor a "su" sector.

## Qué queda permitido al vendedor

- **Sector**: solo actualizar un sector existente y solo los campos de la tabla; `turnoCerrado` y `stockInicialIngresado` solo pueden pasar a `true`.
- **Stock, bandejeros, rondas**: crear y actualizar (el stock solo con el sector abierto). Borrar stock, bandejeros o rondas es solo admin.
- **Mermas, transacciones**: solo crear. Editar o borrar es solo admin.
- **Traspasos**: crear como `pendiente`; confirmar una sola vez sin tocar lo enviado.
- **Stock inicial**: la carga (cantidades absolutas) se bloquea en la app si el sector tiene cierre, ventas, traspasos salientes, entrantes pendientes, rondas, mermas o reposiciones (`StockService.bloqueosStockInicial`). No está en las reglas: requiere consultas.
- **Historial de cierres**: se crea solo en la misma escritura que cierra el sector con ese `cierreId`; todos lo leen, nadie lo edita ni lo borra. Las estadísticas del admin suman todos los turnos desde aquí.
- **Movimientos**: solo el admin crea reposiciones (`tipo: 'reposicion'`, `adminUid` = su uid, cantidad entera > 0, sector abierto, y el stock del producto sube exactamente esa cantidad en la misma escritura). Todos los leen; nadie los edita ni los borra.
- **Incidencias** (`discrepancias`): el vendedor solo crea la suya (`vendedorUid` = su uid, `estado: 'pendiente'`, diferencia > 0). `faltante_traspaso`: id = traspaso, diferencia = enviado − recibido, origen realmente cerrado. `sobrante_conteo`: id = `{cierreId}_{productoId}`, diferencia = contado − stock del sistema, y solo en la misma escritura que cierra ese sector con ese `cierreId`. No las lee ni las edita. El admin las lee y las marca resueltas (`incidencias_pendientes.dart`); nadie las borra.
- **Sector con turno cerrado**: el vendedor no escribe su stock, no recibe traspasos entrantes ni los confirma, y no crea salientes pendientes. Sí puede quedar confirmada la copia saliente de un traspaso recibido completo. El admin no tiene estas restricciones.
- **Perfil**: solo sus acumulados de ventas y sus `cierres_contabilizados` (crear, no editar).
- **Username**: el id siempre va normalizado (minúsculas, sin espacios), también para el admin. Crear solo el que coincide con el `username` de su propio perfil (tras el batch), con su email de Auth y sin sobrescribir uno existente. Nadie puede listar `usernames/`; editar o borrar es solo admin.

## Migración

`scripts/migrar_usernames.mjs` genera `usernames/` desde `usuarios/`. Sin `--aplicar` solo simula. También crea el id normalizado de documentos `usernames/` existentes que no lo estén (p. ej. `Paz` → `paz`) y lista los originales para borrarlos a mano. No sobrescribe y reporta perfiles sin email y usernames repetidos con correos distintos, que hay que resolver a mano.
