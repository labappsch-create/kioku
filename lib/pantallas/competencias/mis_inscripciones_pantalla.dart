import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';
import 'ocultar_torneo.dart';
import 'ver_competencia_pantalla.dart';

/// Pantalla 11: mis inscripciones, con su estado.
class MisInscripcionesPantalla extends StatefulWidget {
  const MisInscripcionesPantalla({
    super.key,
    required this.uid,
    required this.perfil,
  });

  final String uid;
  final Perfil perfil;

  @override
  State<MisInscripcionesPantalla> createState() => _MisInscripcionesPantallaState();
}

class _MisInscripcionesPantallaState extends State<MisInscripcionesPantalla> {
  final _servicio = CompetenciasServicio();
  bool _verOcultos = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis inscripciones')),
      body: StreamBuilder<List<Inscripcion>>(
        stream: _servicio.deAtleta(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final todas = snap.data;
          if (todas == null) return const Center(child: CircularProgressIndicator());
          return ValueListenableBuilder<int>(
            valueListenable: Sesion.cambios,
            builder: (context, _, __) {
              final ocultas = {
                for (final i in todas)
                  if (estaOculto(i.competenciaId)) i.competenciaId,
              };
              final lista = _verOcultos
                  ? todas
                  : todas.where((i) => !estaOculto(i.competenciaId)).toList();
              final pie = BotonVerOcultos(
                cantidad: ocultas.length,
                mostrando: _verOcultos,
                alCambiar: () => setState(() => _verOcultos = !_verOcultos),
              );
              if (lista.isEmpty) {
                return ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        todas.isEmpty
                            ? 'Aún no tienes inscripciones.'
                            : 'No hay inscripciones para mostrar.',
                        textAlign: TextAlign.center),
                  ),
                  pie,
                ]);
              }
              return ListView.separated(
                itemCount: lista.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == lista.length) return pie;
                  return _Fila(
                    inscripcion: lista[i],
                    uid: widget.uid,
                    perfil: widget.perfil,
                    servicio: _servicio,
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

class _Fila extends StatelessWidget {
  const _Fila({
    required this.inscripcion,
    required this.uid,
    required this.perfil,
    required this.servicio,
  });

  final Inscripcion inscripcion;
  final String uid;
  final Perfil perfil;
  final CompetenciasServicio servicio;

  @override
  Widget build(BuildContext context) {
    final ins = inscripcion;
    return StreamBuilder<Competencia?>(
      stream: servicio.ver(ins.competenciaId),
      builder: (context, cs) {
        final c = cs.data;
        final fecha = c?.textoFechas ?? textoFecha(ins.fechaInicio);
        String estado = ins.textoEstado;
        IconData icono = ins.confirmada ? Icons.verified : Icons.hourglass_top;
        if (c != null && c.cancelada) {
          estado = 'Torneo cancelado';
          icono = Icons.cancel;
        } else if (c != null && c.suspendida) {
          estado = 'Torneo suspendido · $estado';
          icono = Icons.pause_circle;
        }
        final oculto = estaOculto(ins.competenciaId);
        if (oculto) icono = Icons.visibility_off;
        return ListTile(
          leading: Icon(icono),
          title: Text(ins.competenciaNombre),
          subtitle: Text('${ins.categoriaNombre}\n$fecha · $estado'
              '${oculto ? ' · Oculto' : ''}'),
          isThreeLine: true,
          trailing: MenuOcultar(competencia: c),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VerCompetenciaPantalla(
                  competenciaId: ins.competenciaId, uid: uid, perfil: perfil))),
        );
      },
    );
  }
}
