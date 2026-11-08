import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import 'ver_competencia_pantalla.dart';

/// Pantalla 11: mis inscripciones, con su estado.
class MisInscripcionesPantalla extends StatelessWidget {
  const MisInscripcionesPantalla({
    super.key,
    required this.uid,
    required this.perfil,
  });

  final String uid;
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final servicio = CompetenciasServicio();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis inscripciones')),
      body: StreamBuilder<List<Inscripcion>>(
        stream: servicio.deAtleta(uid),
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
                child: Text('Aún no tienes inscripciones.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ins = lista[i];
              return ListTile(
                leading: Icon(ins.confirmada ? Icons.verified : Icons.hourglass_top),
                title: Text(ins.competenciaNombre),
                subtitle: Text('${ins.categoriaNombre}\n'
                    '${textoFecha(ins.fechaInicio)} · ${ins.textoEstado}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VerCompetenciaPantalla(
                        competenciaId: ins.competenciaId,
                        uid: uid,
                        perfil: perfil))),
              );
            },
          );
        },
      ),
    );
  }
}
