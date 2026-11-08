import 'package:flutter/material.dart';

import '../modelos/perfil.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../widgets/tarjeta_perfil.dart';

/// Muestra el perfil público de una persona a partir de su identificador.
class VerPerfilPantalla extends StatelessWidget {
  const VerPerfilPantalla({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: StreamBuilder<PerfilPublico?>(
        stream: PerfilesServicio().verPublico(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('Este perfil no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [TarjetaPerfil(perfil: p)],
          );
        },
      ),
    );
  }
}
