// Admin: ver los usuarios y cambiar su rol (vendedor ↔ administrador).
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/roles_service.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

class GestionRolesUsuarios extends StatefulWidget {
  const GestionRolesUsuarios({super.key, this.firestore, this.miUid});

  /// Solo para tests: otra base (p. ej. FakeFirebaseFirestore).
  @visibleForTesting
  final FirebaseFirestore? firestore;

  /// Solo para tests: uid de la sesión.
  @visibleForTesting
  final String? miUid;

  @override
  State<GestionRolesUsuarios> createState() => _GestionRolesUsuariosState();
}

class _GestionRolesUsuariosState extends State<GestionRolesUsuarios> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;
  String? _error;

  /// Perfil cuyo rol se está guardando (deshabilita su botón).
  String? _guardando;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;
  String? get _miUid =>
      widget.miUid ??
      (widget.firestore == null ? FirebaseAuth.instance.currentUser?.uid : null);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _db.collection('usuarios').get();
      if (!mounted) return;
      final list = snap.docs;
      // Administradores primero; dentro, por nombre.
      list.sort((a, b) {
        final adminA = _esAdmin(a.data()) ? 0 : 1;
        final adminB = _esAdmin(b.data()) ? 0 : 1;
        if (adminA != adminB) return adminA - adminB;
        return _nombre(a).toLowerCase().compareTo(_nombre(b).toLowerCase());
      });
      setState(() {
        _docs = list;
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

  static bool _esAdmin(Map<String, dynamic> data) =>
      AuthManager.esAdmin(AuthManager.normalizarRol(data['rol']?.toString()));

  static String _nombre(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      (doc.data()['username'] ?? doc.data()['email'] ?? doc.id).toString();

  Future<void> _cambiarRol(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final aAdmin = !_esAdmin(doc.data());
    final nombre = _nombre(doc);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aAdmin ? '¿Hacer administrador?' : '¿Pasar a vendedor?'),
        content: Text(
          aAdmin
              ? '$nombre podrá modificar todo: productos, stock, eventos y '
                    'usuarios. Entregue este rol solo a quien lo necesite.'
              : '$nombre dejará de ver el panel de administración. La próxima '
                    'vez que ingrese entrará como vendedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aAdmin ? 'Hacer administrador' : 'Pasar a vendedor'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _guardando = doc.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await RolesService(_db).cambiarRol(
        perfilId: doc.id,
        aAdmin: aAdmin,
        miUid: _miUid,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            aAdmin
                ? '$nombre ahora es administrador.'
                : '$nombre ahora es vendedor.',
          ),
          backgroundColor: AppColors.exitoFuerte,
        ),
      );
      await _cargar();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is RolException ? e.mensaje : 'No se pudo cambiar el rol: $e',
          ),
          backgroundColor: AppColors.errorFuerte,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios y roles'),
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
              titulo: 'No pudimos cargar los usuarios',
              detalle: _error,
              onReintentar: _cargar,
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: conMargenInferior(context, const EdgeInsets.all(16)),
                children: [
                  Text(
                    'Toque el botón de cada persona para hacerla administradora '
                    'o devolverla a vendedor. Su propio rol no se puede cambiar.',
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppColors.tintaSecundaria,
                      height: 1.35,
                    ),
                  ).entrada(),
                  const SizedBox(height: 16),
                  for (final (i, doc) in _docs.indexed)
                    _tarjeta(doc).entradaEnLista(i + 1),
                ],
              ),
            ),
    );
  }

  Widget _tarjeta(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final esAdmin = _esAdmin(data);
    final esYo = RolesService.esPropio(doc.id, data, _miUid);
    final email = (data['email'] ?? '').toString();
    final color = esAdmin ? AppColors.dorado : AppColors.cian;
    final guardando = _guardando == doc.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(
                    esAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre(doc),
                        style: AppFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.tinta,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: AppFonts.inter(
                            fontSize: 14,
                            color: AppColors.tintaSecundaria,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    esAdmin ? 'Administrador' : 'Vendedor',
                    style: AppFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (esYo)
              Text(
                'Esta es su cuenta: su rol no se puede cambiar desde aquí.',
                style: AppFonts.inter(
                  fontSize: 13,
                  color: AppColors.tintaSecundaria,
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Presionable(
                  child: OutlinedButton.icon(
                    onPressed: guardando ? null : () => _cambiarRol(doc),
                    icon: guardando
                        ? const SizedBox(height: 18, child: CargandoPuntos())
                        : Icon(
                            esAdmin
                                ? Icons.person_outline_rounded
                                : Icons.admin_panel_settings_outlined,
                          ),
                    label: Text(
                      esAdmin ? 'Pasar a vendedor' : 'Hacer administrador',
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
