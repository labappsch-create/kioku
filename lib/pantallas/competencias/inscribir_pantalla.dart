import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';

/// Pantalla 7: inscribirme (el propio atleta).
/// Solo atletas con dojo confirmado.
class InscribirmePantalla extends StatelessWidget {
  const InscribirmePantalla({
    super.key,
    required this.competencia,
    required this.uid,
    required this.perfil,
  });

  final Competencia competencia;
  final String uid;
  final Perfil perfil;

  Widget _mensaje(String texto) => Scaffold(
        appBar: AppBar(title: const Text('Inscribirme')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(texto, textAlign: TextAlign.center),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dojoId = perfil.dojoId;
    if (dojoId == null) {
      return _mensaje(
          'Para inscribirte necesitas tener tu dojo confirmado.\n\n'
          'Ve a Mi perfil → Editar perfil → "Buscar mi dojo en Kioku", '
          'y espera a que tu sensei te acepte.');
    }
    if (perfil.sexo == null) {
      return _mensaje('Completa el dato "Sexo" en tu perfil para inscribirte.');
    }
    final servicio = DojosServicio();
    return StreamBuilder<String?>(
      stream: servicio.estadoMiembro(dojoId, uid),
      builder: (context, estado) {
        if (estado.connectionState == ConnectionState.waiting) {
          return _mensaje('Revisando tu dojo...');
        }
        if (estado.data != estadoConfirmado) {
          return _mensaje(
              'Tu dojo "${perfil.dojo}" aún no confirma tu solicitud.\n\n'
              'Solo pueden inscribirse atletas con dojo confirmado.');
        }
        return StreamBuilder<DojoPublico?>(
          stream: servicio.ver(dojoId),
          builder: (context, dojo) {
            if (dojo.hasError) return _mensaje(mensajeDeError(dojo.error!));
            final d = dojo.data;
            if (d == null) return _mensaje('Cargando...');
            final hoy = DateTime.now();
            return InscribirPantalla(
              titulo: 'Inscribirme',
              competencia: competencia,
              atleta: DatosAtleta(
                uid: uid,
                nombre: perfil.nombrePublico(hoy),
                gradoId: perfil.gradoId,
                edad: calcularEdad(perfil.fechaNacimiento, hoy),
                pesoKg: perfil.pesoKg,
                estaturaCm: perfil.estaturaCm,
                sexo: perfil.sexo!.name,
              ),
              dojoId: d.id,
              dojoNombre: d.nombre,
              senseiUid: d.senseiUid,
              inscritoPor: uid,
            );
          },
        );
      },
    );
  }
}

/// Elegir una categoría por modalidad para un atleta.
/// La usan el propio atleta y su sensei.
class InscribirPantalla extends StatelessWidget {
  const InscribirPantalla({
    super.key,
    required this.titulo,
    required this.competencia,
    required this.atleta,
    required this.dojoId,
    required this.dojoNombre,
    required this.senseiUid,
    required this.inscritoPor,
  });

  final String titulo;
  final Competencia competencia;
  final DatosAtleta atleta;
  final String dojoId;
  final String dojoNombre;
  final String senseiUid;
  final String inscritoPor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final abiertas =
        competencia.estado(DateTime.now()) == EstadoCompetencia.abiertas;
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: StreamBuilder<List<Categoria>>(
        stream: CompetenciasServicio().categorias(competencia.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final categorias = snap.data;
          if (categorias == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(competencia.nombre, style: textos.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(atleta.nombre),
                  subtitle: Text('${atleta.resumen}\n$dojoNombre'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Solo se muestran las categorías que calzan con la edad, el peso, '
                'el sexo y el grado. Una categoría por modalidad.',
                style: textos.bodySmall,
              ),
              if (!abiertas) ...[
                const SizedBox(height: 8),
                Text('Las inscripciones están cerradas.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              for (final m in competencia.modalidadesElegidas)
                _SeccionModalidad(
                  pantalla: this,
                  modalidad: m,
                  abiertas: abiertas,
                  categorias: [
                    for (final c in categorias)
                      if (c.modalidad == m && c.calza(atleta)) c,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SeccionModalidad extends StatefulWidget {
  const _SeccionModalidad({
    required this.pantalla,
    required this.modalidad,
    required this.abiertas,
    required this.categorias,
  });

  final InscribirPantalla pantalla;
  final String modalidad;
  final bool abiertas;
  final List<Categoria> categorias;

  @override
  State<_SeccionModalidad> createState() => _SeccionModalidadState();
}

class _SeccionModalidadState extends State<_SeccionModalidad> {
  final _servicio = CompetenciasServicio();
  String? _elegida;
  bool _trabajando = false;

  Future<void> _hacer(Future<void> Function() accion, String listo) async {
    final mensajes = ScaffoldMessenger.of(context);
    setState(() => _trabajando = true);
    try {
      await accion();
      mensajes.showSnackBar(SnackBar(content: Text(listo)));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pantalla;
    final textos = Theme.of(context).textTheme;
    final id = idInscripcion(p.competencia.id, p.atleta.uid, widget.modalidad);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: StreamBuilder<Inscripcion?>(
        stream: _servicio.verInscripcion(id),
        builder: (context, snap) {
          final titulo = Text(nombreModalidad(widget.modalidad),
              style: textos.titleMedium);
          if (snap.hasError) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titulo,
              Text(mensajeDeError(snap.error!)),
            ]);
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titulo,
              const LinearProgressIndicator(),
            ]);
          }
          final inscripcion = snap.data;
          if (inscripcion != null) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titulo,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(inscripcion.confirmada
                    ? Icons.verified
                    : Icons.hourglass_top),
                title: Text(inscripcion.categoriaNombre),
                subtitle: Text(inscripcion.confirmada
                    ? 'Confirmada ✓'
                    : 'Pendiente: el organizador debe confirmarla'),
              ),
              if (!inscripcion.confirmada)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _trabajando
                        ? null
                        : () => _hacer(() => _servicio.anular(inscripcion),
                            'Inscripción anulada'),
                    child: const Text('Anular inscripción'),
                  ),
                ),
            ]);
          }
          if (!widget.abiertas) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titulo,
              const Text('Sin inscripción.'),
            ]);
          }
          if (widget.categorias.isEmpty) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              titulo,
              const Text('No hay categorías de esta modalidad que calcen.'),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titulo,
            RadioGroup<String>(
              groupValue: _elegida,
              onChanged: (v) => setState(() => _elegida = v),
              child: Column(children: [
                for (final c in widget.categorias)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: c.id,
                    title: Text(c.nombre),
                  ),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _trabajando || _elegida == null
                    ? null
                    : () {
                        final cat =
                            widget.categorias.firstWhere((c) => c.id == _elegida);
                        _hacer(
                          () => _servicio.inscribir(
                            competencia: p.competencia,
                            categoria: cat,
                            atleta: p.atleta,
                            dojoId: p.dojoId,
                            dojoNombre: p.dojoNombre,
                            senseiUid: p.senseiUid,
                            inscritoPor: p.inscritoPor,
                          ),
                          'Inscripción enviada. Queda pendiente hasta que el organizador la confirme.',
                        );
                      },
                child: Text('Inscribir en ${nombreModalidad(widget.modalidad).toLowerCase()}'),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
