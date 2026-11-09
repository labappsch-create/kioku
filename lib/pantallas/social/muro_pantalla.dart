import 'package:flutter/material.dart';

import '../../modelos/publicacion.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/tarjeta_publicacion.dart';
import 'amigos_pantalla.dart';
import 'crear_publicacion_pantalla.dart';

/// Pantalla 1: el muro (pestaña "Muro").
class MuroPantalla extends StatefulWidget {
  const MuroPantalla({super.key});

  @override
  State<MuroPantalla> createState() => _MuroPantallaState();
}

class _MuroPantallaState extends State<MuroPantalla> {
  final _servicio = SocialServicio();
  Future<List<Publicacion>>? _carga;
  String _firma = '';

  @override
  void initState() {
    super.initState();
    Sesion.cambios.addListener(_siCambio);
    _cargar();
  }

  @override
  void dispose() {
    Sesion.cambios.removeListener(_siCambio);
    super.dispose();
  }

  /// Recarga si cambiaron los amigos, los dojos seguidos o los bloqueos.
  void _siCambio() {
    final r = Sesion.relaciones;
    if (r == null) return;
    final firma = [
      (r.amigos.toList()..sort()).join(','),
      (r.siguiendo.keys.toList()..sort()).join(','),
      (r.bloqueados.toList()..sort()).join(','),
    ].join('|');
    if (firma != _firma) _cargar();
  }

  Future<void> _cargar() async {
    final uid = Sesion.uid;
    final r = Sesion.relaciones;
    if (uid == null || r == null) return;
    _firma = [
      (r.amigos.toList()..sort()).join(','),
      (r.siguiendo.keys.toList()..sort()).join(','),
      (r.bloqueados.toList()..sort()).join(','),
    ].join('|');
    final perfil = Sesion.perfil;
    final miDojo = perfil?.dojoEstado == 'confirmado' ? perfil?.dojoId : null;
    final f = _servicio.muro(
      yo: uid,
      amigos: r.amigos,
      bloqueados: r.bloqueados,
      miDojo: miDojo,
      dojosSeguidos: r.siguiendo.keys,
    );
    setState(() => _carga = f);
    await f;
  }

  Future<void> _publicar() async {
    final r = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CrearPublicacionPantalla()));
    if (r == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final r = Sesion.relaciones;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muro'),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: Sesion.cambios,
            builder: (context, _, __) {
              final n = Sesion.relaciones?.recibidas.length ?? 0;
              return IconButton(
                tooltip: 'Amigos',
                icon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.group),
                ),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AmigosPantalla())),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit),
        label: const Text('Publicar'),
        onPressed: _publicar,
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
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
            return ListView(
              padding: const EdgeInsets.only(bottom: 88, top: 4),
              children: [
                if (r?.suspendido ?? false)
                  Card(
                    margin: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'Tu cuenta está suspendida por un administrador: no puedes '
                          'publicar, comentar ni enviar solicitudes de amistad.'),
                    ),
                  ),
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Tu muro está vacío.\n\nAgrega amigos (búscalos en Gente), '
                      'sigue dojos o publica algo tú.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final p in lista)
                  TarjetaPublicacion(publicacion: p, alCambiar: _cargar),
              ],
            );
          },
        ),
      ),
    );
  }
}
