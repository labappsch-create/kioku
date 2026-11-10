import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';
import 'editar_competencia_pantalla.dart';
import 'ocultar_torneo.dart';
import 'ver_competencia_pantalla.dart';

/// Las competencias que organiza la persona.
class MisCompetenciasPantalla extends StatefulWidget {
  const MisCompetenciasPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  State<MisCompetenciasPantalla> createState() => _MisCompetenciasPantallaState();
}

class _MisCompetenciasPantallaState extends State<MisCompetenciasPantalla> {
  bool _verOcultos = false;

  String get uid => widget.uid;
  Perfil get perfil => widget.perfil;

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
          final todas = snap.data;
          if (todas == null) return const Center(child: CircularProgressIndicator());
          return ValueListenableBuilder<int>(
            valueListenable: Sesion.cambios,
            builder: (context, _, __) {
          final nOcultos = todas.where((c) => estaOculto(c.id)).length;
          final lista =
              _verOcultos ? todas : todas.where((c) => !estaOculto(c.id)).toList();
          final pie = BotonVerOcultos(
            cantidad: nOcultos,
            mostrando: _verOcultos,
            alCambiar: () => setState(() => _verOcultos = !_verOcultos),
          );
          if (lista.isEmpty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    todas.isEmpty
                        ? 'Aún no organizas ninguna competencia.'
                        : 'No hay competencias para mostrar.',
                    textAlign: TextAlign.center),
              ),
              pie,
            ]);
          }
          final ahora = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == lista.length) return pie;
              final c = lista[i];
              final oculto = estaOculto(c.id);
              return ListTile(
                leading: Icon(oculto ? Icons.visibility_off : Icons.emoji_events),
                title: Text(c.nombre),
                subtitle: Text('${nombreNivel(c.nivel)} · ${c.textoFechas}\n'
                    '${nombreEstado(c.estado(ahora))}${oculto ? ' · Oculto' : ''}'),
                isThreeLine: true,
                trailing: MenuOcultar(competencia: c),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VerCompetenciaPantalla(
                        competenciaId: c.id, uid: uid, perfil: perfil))),
              );
            },
          );
            },
          );
        },
      ),
    );
  }
}
