import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import 'editar_competencia_pantalla.dart';
import 'ver_competencia_pantalla.dart';

/// Las competencias que organiza la persona.
class MisCompetenciasPantalla extends StatelessWidget {
  const MisCompetenciasPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis competencias')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Crear competencia'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EditarCompetenciaPantalla(uid: uid, perfil: perfil))),
      ),
      body: StreamBuilder<List<Competencia>>(
        stream: CompetenciasServicio().deOrganizador(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final lista = snap.data;
          if (lista == null) return const Center(child: CircularProgressIndicator());
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no organizas ninguna competencia.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final ahora = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = lista[i];
              return ListTile(
                leading: const Icon(Icons.emoji_events),
                title: Text(c.nombre),
                subtitle: Text('${nombreNivel(c.nivel)} · ${c.textoFechas}\n'
                    '${nombreEstado(c.estado(ahora))}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VerCompetenciaPantalla(
                        competenciaId: c.id, uid: uid, perfil: perfil))),
              );
            },
          );
        },
      ),
    );
  }
}
