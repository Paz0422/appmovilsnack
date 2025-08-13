import 'package:flutter/material.dart';
// --- Archivo: vendor_home_screen.dart ---

class HomeVendedor extends StatefulWidget {
  // Más adelante, aquí recibiremos los datos del evento desde la pantalla de login
  const HomeVendedor({super.key});

  @override
  State<HomeVendedor> createState() => _HomeVendedorState();
}

class _HomeVendedorState extends State<HomeVendedor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Vendedor'),
        automaticallyImplyLeading: false,
      ),
      // Usamos Padding para dar un poco de espacio en los bordes
      body: Padding(padding: const EdgeInsets.all(16.0)),
    );
  }
}
