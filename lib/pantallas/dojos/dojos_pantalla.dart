import 'package:flutter/material.dart';

import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import 'buscar_dojos_pantalla.dart';
import 'editar_dojo_pantalla.dart';
import 'ver_dojo_pantalla.dart';

bool esEntrenador(Perfil p) => p.rol == Rol.entrenador || p.rol == Rol.ambos;

/// Pestaña "Dojos": buscar dojos y, para entrenadores, "Mis dojos".
class DojosPantalla extends StatelessWidget {
  const DojosPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    return BuscarDojosPantalla(
      acciones: [
        TextButton.icon(
          icon: const Icon(Icons.house),
          label: const Text('Mis dojos'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MisDojosPantalla(uid: uid, perfil: perfil))),
        ),
      ],
    );
  }
}

/// Pantalla 2: los dojos que administra el sensei.
class MisDojosPantalla extends StatelessWidget {
  const MisDojosPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final entrenador = esEntrenador(perfil);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis dojos')),
      floatingActionButton: entrenador
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Crear dojo'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      EditarDojoPantalla(perfilSensei: perfil, uid: uid))),
            )
          : null,
      body: !entrenador
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo los entrenadores pueden crear dojos.\n\n'
                  'Si eres entrenador, ve a "Mi perfil", toca "Editar perfil" '
                  'y elige el rol "Entrenador" o "Atleta y entrenador".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<List<DojoPublico>>(
              stream: DojosServicio().misDojos(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(mensajeDeError(snap.error!),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final lista = snap.data;
                if (lista == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (lista.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no has creado ningún dojo.\nToca "Crear dojo" para empezar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = lista[i];
                    return ListTile(
                      leading: const Icon(Icons.sports_martial_arts),
                      title: Text(d.nombre),
                      subtitle: StreamBuilder<List<Miembro>>(
                        stream: DojosServicio().miembros(d.id, estadoPendiente),
                        builder: (context, s) {
                          final n = s.data?.length ?? 0;
                          return Text(n == 0
                              ? d.lugar
                              : '${d.lugar}\n$n solicitudes nuevas');
                        },
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VerDojoPantalla(dojoId: d.id))),
                    );
                  },
                );
              },
            ),
    );
  }
}
