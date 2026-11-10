import 'package:flutter/material.dart';

import '../modelos/dojo.dart';
import '../servicios/admin_servicio.dart';
import '../servicios/dojos_servicio.dart';
import '../servicios/sesion.dart';
import 'buscar_todo_pantalla.dart';
import 'competencias/editar_competencia_pantalla.dart';
import 'dojos/dojos_pantalla.dart' show esEntrenador;
import 'dojos/editar_dojo_pantalla.dart';
import 'social/crear_publicacion_pantalla.dart';

/// Botón "+" de la barra de arriba: atajos para crear cosas.
/// Cada persona ve solo las opciones que puede usar.
class BotonCrear extends StatelessWidget {
  const BotonCrear({super.key, this.alPublicar});

  /// Se llama después de publicar (por ejemplo, para recargar el muro).
  final VoidCallback? alPublicar;

  Future<void> _publicar(BuildContext context, Widget pantalla) async {
    final r = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => pantalla));
    if (r == true) alPublicar?.call();
  }

  Future<void> _publicarComoDojo(BuildContext context, List<DojoPublico> dojos) async {
    DojoPublico? elegido = dojos.length == 1 ? dojos.first : null;
    elegido ??= await showModalBottomSheet<DojoPublico>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('¿A nombre de qué dojo?')),
          for (final d in dojos)
            ListTile(
              leading: const Icon(Icons.sports_martial_arts),
              title: Text(d.nombre),
              onTap: () => Navigator.of(ctx).pop(d),
            ),
        ]),
      ),
    );
    if (elegido == null || !context.mounted) return;
    await _publicar(
        context, CrearPublicacionPantalla(dojo: DojoQuePublica(elegido.id, elegido.nombre)));
  }

  Future<void> _abrirMenu(BuildContext context) async {
    final uid = Sesion.uid;
    final perfil = Sesion.perfil;
    if (uid == null || perfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todavía se está cargando tu perfil. Prueba de nuevo en un momento.')));
      return;
    }
    final navegador = Navigator.of(context);

    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: StreamBuilder<List<DojoPublico>>(
          stream: DojosServicio().misDojos(uid),
          builder: (ctx, dojos) => StreamBuilder<bool>(
            stream: AdminServicio().esOrganizador(uid),
            builder: (ctx, org) {
              final misDojos = dojos.data ?? const <DojoPublico>[];
              final puedeTorneo = misDojos.isNotEmpty || org.data == true;
              ListTile item(String valor, IconData icono, String texto, [String? sub]) =>
                  ListTile(
                    leading: CircleAvatar(child: Icon(icono)),
                    title: Text(texto),
                    subtitle: sub == null ? null : Text(sub),
                    onTap: () => Navigator.of(ctx).pop(valor),
                  );
              return Column(mainAxisSize: MainAxisSize.min, children: [
                item('publicacion', Icons.edit, 'Publicación', 'Texto y fotos'),
                item('foto', Icons.photo_library, 'Publicación con foto',
                    'Elige fotos de tu galería'),
                if (misDojos.isNotEmpty)
                  item('dojo', Icons.campaign, 'Publicar como dojo'),
                if (puedeTorneo) item('torneo', Icons.emoji_events, 'Crear torneo'),
                if (esEntrenador(perfil))
                  item('crear_dojo', Icons.sports_martial_arts, 'Crear dojo'),
                if (!dojos.hasData || !org.hasData)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 8),
              ]);
            },
          ),
        ),
      ),
    );
    if (opcion == null || !context.mounted) return;

    switch (opcion) {
      case 'publicacion':
        await _publicar(context, const CrearPublicacionPantalla());
      case 'foto':
        await _publicar(context, const CrearPublicacionPantalla(elegirFotosAlAbrir: true));
      case 'dojo':
        final dojos = await DojosServicio().misDojos(uid).first;
        if (context.mounted) await _publicarComoDojo(context, dojos);
      case 'torneo':
        navegador.push(MaterialPageRoute(
            builder: (_) => EditarCompetenciaPantalla(uid: uid, perfil: perfil)));
      case 'crear_dojo':
        navegador.push(MaterialPageRoute(
            builder: (_) => EditarDojoPantalla(perfilSensei: perfil, uid: uid)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Crear',
      icon: const Icon(Icons.add_circle_outline),
      onPressed: () => _abrirMenu(context),
    );
  }
}

/// Lupa de la barra de arriba: busca personas, dojos y torneos.
class BotonBuscar extends StatelessWidget {
  const BotonBuscar({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Buscar',
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BuscarTodoPantalla())),
    );
  }
}
