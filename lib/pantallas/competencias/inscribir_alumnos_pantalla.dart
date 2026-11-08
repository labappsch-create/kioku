import 'package:flutter/material.dart';

import '../../datos/grados.dart';
import '../../modelos/competencia.dart';
import '../../modelos/dojo.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../widgets/tarjeta_perfil.dart';
import 'inscribir_pantalla.dart';

/// Pantalla 8: el sensei inscribe a los miembros confirmados de su dojo.
class InscribirAlumnosPantalla extends StatefulWidget {
  const InscribirAlumnosPantalla({
    super.key,
    required this.competencia,
    required this.uid,
  });

  final Competencia competencia;
  final String uid;

  @override
  State<InscribirAlumnosPantalla> createState() =>
      _InscribirAlumnosPantallaState();
}

class _InscribirAlumnosPantallaState extends State<InscribirAlumnosPantalla> {
  String? _dojoId;

  Future<void> _abrir(DojoPublico dojo, Miembro m) async {
    final navegador = Navigator.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    try {
      final atleta = await CompetenciasServicio().fichaDeMiembro(
          dojoId: dojo.id, uid: m.uid, nombre: m.nombre, gradoId: m.gradoId);
      if (atleta == null) {
        mensajes.showSnackBar(SnackBar(
            content: Text('${m.nombre} todavía no comparte sus datos para competir. '
                'Pídele que actualice Kioku y lo abra una vez.')));
        return;
      }
      navegador.push(MaterialPageRoute(
        builder: (_) => InscribirPantalla(
          titulo: 'Inscribir a ${m.nombre}',
          competencia: widget.competencia,
          atleta: atleta,
          dojoId: dojo.id,
          dojoNombre: dojo.nombre,
          senseiUid: widget.uid,
          inscritoPor: widget.uid,
        ),
      ));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = DojosServicio();
    return Scaffold(
      appBar: AppBar(title: const Text('Inscribir a mis alumnos')),
      body: StreamBuilder<List<DojoPublico>>(
        stream: servicio.misDojos(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final dojos = snap.data;
          if (dojos == null) return const Center(child: CircularProgressIndicator());
          if (dojos.isEmpty) {
            return const Center(child: Text('No tienes dojos en Kioku.'));
          }
          final dojo = dojos.firstWhere((d) => d.id == _dojoId,
              orElse: () => dojos.first);
          return Column(children: [
            if (dojos.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: dojo.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Dojo', border: OutlineInputBorder()),
                  items: [
                    for (final d in dojos)
                      DropdownMenuItem(value: d.id, child: Text(d.nombre)),
                  ],
                  onChanged: (v) => setState(() => _dojoId = v),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<Miembro>>(
                stream: servicio.miembros(dojo.id, estadoConfirmado),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text(mensajeDeError(snap.error!)));
                  }
                  final lista = snap.data;
                  if (lista == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (lista.isEmpty) {
                    return const Center(
                        child: Text('Este dojo aún no tiene miembros confirmados.'));
                  }
                  return ListView.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = lista[i];
                      final grado = gradoPorId(m.gradoId);
                      return ListTile(
                        leading: grado == null ? null : Cinturon(grado: grado),
                        title: Text(m.nombre),
                        subtitle: Text(grado?.nombre ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrir(dojo, m),
                      );
                    },
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
