import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../modelos/dojo.dart';
import '../../modelos/publicacion.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/tarjeta_publicacion.dart';

/// Pantalla 11: el sensei ve (y puede borrar) las publicaciones de sus
/// alumnos menores de edad.
class AlumnosMenoresPantalla extends StatefulWidget {
  const AlumnosMenoresPantalla({super.key, required this.uid});

  final String uid;

  @override
  State<AlumnosMenoresPantalla> createState() => _AlumnosMenoresPantallaState();
}

class _AlumnosMenoresPantallaState extends State<AlumnosMenoresPantalla> {
  late Future<List<Publicacion>> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<List<Publicacion>> _cargar() async {
    final db = FirebaseFirestore.instance;
    final dojos = await DojosServicio().misDojos(widget.uid).first;
    final menores = <String>{};
    for (final d in dojos) {
      final miembros = await DojosServicio().miembros(d.id, estadoConfirmado).first;
      for (final m in miembros) {
        final ficha =
            await db.collection('dojos').doc(d.id).collection('fichas').doc(m.uid).get();
        final edad = (ficha.data()?['edad'] as num?)?.toInt();
        if (edad != null && edad < 18) menores.add(m.uid);
      }
    }
    final todas = <Publicacion>[];
    for (final u in menores) {
      try {
        todas.addAll(await SocialServicio().dePersona(u, completo: true));
      } catch (_) {}
    }
    todas.sort((a, b) => a.id.compareTo(b.id));
    return todas;
  }

  void _recargar() => setState(() => _carga = _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alumnos menores')),
      body: RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: FutureBuilder<List<Publicacion>>(
          future: _carga,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(mensajeDeError(snap.error!), textAlign: TextAlign.center),
                ),
              ]);
            }
            final lista = snap.data ?? const <Publicacion>[];
            return ListView(children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Publicaciones de los alumnos menores de 18 de tus dojos. '
                    'Puedes borrarlas o borrar sus comentarios si es necesario.'),
              ),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Tus alumnos menores no han publicado nada.',
                      textAlign: TextAlign.center),
                ),
              for (final p in lista)
                TarjetaPublicacion(publicacion: p, puedeModerar: true, alCambiar: _recargar),
            ]);
          },
        ),
      ),
    );
  }
}
