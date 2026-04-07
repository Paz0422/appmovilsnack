// Admin: gestionar roles de usuarios (vendedor / encargado)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class GestionRolesUsuarios extends StatefulWidget {
  const GestionRolesUsuarios({super.key});

  @override
  State<GestionRolesUsuarios> createState() => _GestionRolesUsuariosState();
}

class _GestionRolesUsuariosState extends State<GestionRolesUsuarios> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;
  String? _error;
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);

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
      final snap = await FirebaseFirestore.instance.collection('usuarios').get();
      if (mounted) {
        final list = snap.docs;
        list.sort((a, b) {
          final na = (a.data()['username'] ?? a.data()['email'] ?? '').toString().toLowerCase();
          final nb = (b.data()['username'] ?? b.data()['email'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
        setState(() {
          _docs = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _cambiarRol(String uid, String nuevoRol) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'rol': nuevoRol,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol actualizado a $nuevoRol'),
            backgroundColor: Colors.green,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Roles de usuarios',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: GoogleFonts.poppins(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _cargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Asigna el rol de cada usuario. Solo vendedor y encargado se pueden cambiar desde aquí.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._docs.map((doc) {
                        final data = doc.data();
                        final uid = doc.id;
                        final username =
                            (data['username'] ?? data['email'] ?? uid).toString();
                        final email = (data['email'] ?? '').toString();
                        final rol = (data['rol'] ?? 'vendedor').toString();
                        final esAdmin = rol == 'admin';
                        final esYo = uid == currentUid;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: esAdmin
                                      ? accentColor
                                      : primaryColor.withOpacity(0.2),
                                  child: Icon(
                                    esAdmin ? Icons.admin_panel_settings : Icons.person,
                                    color: esAdmin ? primaryColor : primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: primaryColor,
                                        ),
                                      ),
                                      if (email.isNotEmpty)
                                        Text(
                                          email,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (esAdmin || esYo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (esAdmin ? accentColor : Colors.grey)
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      esAdmin ? 'Admin' : 'Tú',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: primaryColor,
                                      ),
                                    ),
                                  )
                                else
                                  _DropdownRol(
                                    rolActual: rol,
                                    onCambiar: (nuevoRol) =>
                                        _cambiarRol(uid, nuevoRol),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
class _DropdownRol extends StatelessWidget {
  final String rolActual;
  final ValueChanged<String> onCambiar;

  const _DropdownRol({
    required this.rolActual,
    required this.onCambiar,
  });

  static const List<String> roles = ['vendedor', 'encargado'];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2B2B2B);

    return DropdownButton<String>(
      value: roles.contains(rolActual) ? rolActual : 'vendedor',
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
      items: roles.map((r) {
        return DropdownMenuItem<String>(
          value: r,
          child: Text(
            r == 'encargado' ? 'Encargado' : 'Vendedor',
            style: GoogleFonts.poppins(fontSize: 14, color: primaryColor),
          ),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value != null && value != rolActual) {
          onCambiar(value);
        }
      },
    );
  }
}

