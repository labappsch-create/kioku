import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';

/// Pantallas 9 y 10: inscritos de una competencia.
/// - Organizador: todos, con Confirmar y Anular.
/// - Sensei: los de sus dojos, con Anular si siguen pendientes.
class InscritosPantalla extends StatelessWidget {
  const InscritosPantalla({
    super.key,
    required this.competencia,
    required this.uid,
    required this.comoOrganizador,
  });

  final Competencia competencia;
  final String uid;
  final bool comoOrganizador;

  Future<void> _hacer(BuildContext context, Future<void> Function() accion,
      String listo, {String? pregunta}) async {
    final mensajes = ScaffoldMessenger.of(context);
    if (pregunta != null) {
      final si = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(pregunta),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí')),
          ],
        ),
      );
      if (si != true) return;
    }
    try {
      await accion();
      mensajes.showSnackBar(SnackBar(content: Text(listo)));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = CompetenciasServicio();
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(comoOrganizador ? 'Inscritos' : 'Inscritos de mis dojos')),
      body: StreamBuilder<List<Inscripcion>>(
        stream: comoOrganizador
            ? servicio.paraOrganizador(competencia.id, uid)
            : servicio.paraSensei(competencia.id, uid),
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
          if (lista == null) return const Center(child: CircularProgressIndicator());
          if (lista.isEmpty) {
            return const Center(child: Text('Aún no hay inscritos.'));
          }
          final pendientes = lista.where((i) => !i.confirmada).length;
          final hijos = <Widget>[
            if (competencia.cancelada || competencia.suspendida)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(12),
                child: Text(competencia.cancelada
                    ? 'Torneo cancelado. Las inscripciones se mantienen como registro.'
                    : 'Torneo suspendido. Nadie puede inscribirse ni anular hasta que se reactive.'),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  '${lista.length} inscripciones · ${lista.length - pendientes} confirmadas · '
                  '$pendientes pendientes'),
            ),
          ];
          String? categoriaActual;
          for (final i in lista) {
            if (i.categoriaNombre != categoriaActual) {
              categoriaActual = i.categoriaNombre;
              hijos.add(Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(categoriaActual, style: textos.titleSmall),
              ));
            }
            hijos.add(ListTile(
              title: Text(i.atletaNombre),
              subtitle: Text('${i.dojoNombre}\n${i.resumenAtleta}\n${i.textoEstado}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'confirmar') {
                    _hacer(context, () => servicio.confirmar(i.id),
                        'Inscripción de ${i.atletaNombre} confirmada');
                  } else if (v == 'anular') {
                    _hacer(context, () => servicio.anular(i),
                        'Inscripción anulada',
                        pregunta: '¿Anular la inscripción de ${i.atletaNombre} '
                            'en "${i.categoriaNombre}"?');
                  }
                },
                itemBuilder: (_) => [
                  if (comoOrganizador && !i.confirmada)
                    const PopupMenuItem(value: 'confirmar', child: Text('Confirmar')),
                  if (comoOrganizador ||
                      (competencia.situacion == situacionNormal &&
                          (!i.confirmada ||
                              competencia.puedeAnularConfirmada(DateTime.now()))))
                    const PopupMenuItem(value: 'anular', child: Text('Anular')),
                ],
              ),
            ));
          }
          return ListView(children: hijos);
        },
      ),
    );
  }
}
