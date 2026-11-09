import 'package:flutter/material.dart';

import '../../modelos/perfil.dart';
import '../../servicios/admin_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/perfiles_servicio.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/tarjeta_publicacion.dart';

/// Pantalla 2: administración (solo administradores).
class AdminPantalla extends StatelessWidget {
  const AdminPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Denuncias'),
            Tab(text: 'Solicitudes'),
            Tab(text: 'Organizadores'),
            Tab(text: 'Administradores'),
            Tab(text: 'Suspendidos'),
          ]),
        ),
        body: const TabBarView(children: [
          _Denuncias(),
          _Solicitudes(),
          _ListaSimple(organizadores: true),
          _ListaSimple(organizadores: false),
          _Suspendidos(),
        ]),
      ),
    );
  }
}

Future<void> _hacer(
    BuildContext context, Future<void> Function() accion, String listo) async {
  final mensajes = ScaffoldMessenger.of(context);
  try {
    await accion();
    mensajes.showSnackBar(SnackBar(content: Text(listo)));
  } catch (e) {
    mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
  }
}

/// Pide el motivo del rechazo. Devuelve null si se cancela.
Future<String?> _pedirMotivo(BuildContext context, String nombre) {
  final texto = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Rechazar a $nombre'),
        content: TextField(
          controller: texto,
          autofocus: true,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Motivo',
            helperText: 'La persona lo verá en un aviso.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: texto.text.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(texto.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirmar(BuildContext context, String pregunta) async {
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
            child: const Text('Sí, quitar')),
      ],
    ),
  );
  return si ?? false;
}

class _Solicitudes extends StatelessWidget {
  const _Solicitudes();

  @override
  Widget build(BuildContext context) {
    final servicio = AdminServicio();
    return StreamBuilder<List<Registro>>(
      stream: servicio.solicitudes(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(mensajeDeError(snap.error!)));
        }
        final lista = snap.data;
        if (lista == null) return const Center(child: CircularProgressIndicator());
        if (lista.isEmpty) {
          return const Center(child: Text('No hay solicitudes pendientes.'));
        }
        return ListView.separated(
          itemCount: lista.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = lista[i];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nombre, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(s.mensaje),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final motivo = await _pedirMotivo(context, s.nombre);
                          if (motivo == null || !context.mounted) return;
                          await _hacer(context,
                              () => servicio.rechazar(s.id, motivo),
                              'Solicitud rechazada');
                        },
                        child: const Text('Rechazar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _hacer(context, () => servicio.aprobar(s),
                            '${s.nombre} ahora es organizador'),
                        child: const Text('Aprobar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ListaSimple extends StatelessWidget {
  const _ListaSimple({required this.organizadores});

  final bool organizadores;

  @override
  Widget build(BuildContext context) {
    final servicio = AdminServicio();
    return Scaffold(
      floatingActionButton: organizadores
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text('Nombrar administrador'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _NombrarAdminPantalla())),
            ),
      body: StreamBuilder<List<Registro>>(
        stream: organizadores
            ? servicio.organizadores()
            : servicio.administradores(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final lista = snap.data;
          if (lista == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (!organizadores)
                const ListTile(
                  leading: Icon(Icons.star),
                  title: Text(correoAdminPrincipal),
                  subtitle: Text('Administrador principal'),
                ),
              if (lista.isEmpty && organizadores)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aún no hay organizadores aprobados.',
                      textAlign: TextAlign.center),
                ),
              for (final r in lista)
                ListTile(
                  leading: Icon(organizadores
                      ? Icons.emoji_events
                      : Icons.admin_panel_settings),
                  title: Text(r.nombre),
                  trailing: IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.person_remove),
                    onPressed: () async {
                      final pregunta = organizadores
                          ? '¿Quitar a ${r.nombre} como organizador? '
                              'Sus competencias siguen existiendo, pero ya no podrá '
                              'crear nuevas regionales, nacionales ni internacionales.'
                          : '¿Quitar a ${r.nombre} como administrador?';
                      if (!await _confirmar(context, pregunta) || !context.mounted) {
                        return;
                      }
                      await _hacer(
                        context,
                        () => organizadores
                            ? servicio.quitarOrganizador(r.id)
                            : servicio.quitarAdmin(r.id),
                        '${r.nombre} fue quitado',
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Busca a una persona por nombre para nombrarla administradora.
class _NombrarAdminPantalla extends StatefulWidget {
  const _NombrarAdminPantalla();

  @override
  State<_NombrarAdminPantalla> createState() => _NombrarAdminPantallaState();
}

class _NombrarAdminPantallaState extends State<_NombrarAdminPantalla> {
  final _texto = TextEditingController();
  Future<List<PerfilPublico>>? _resultados;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() =>
      setState(() => _resultados = PerfilesServicio().buscar(_texto.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nombrar administrador')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _texto,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            decoration: InputDecoration(
              labelText: 'Nombre de la persona',
              border: const OutlineInputBorder(),
              suffixIcon:
                  IconButton(icon: const Icon(Icons.search), onPressed: _buscar),
            ),
          ),
        ),
        Expanded(
          child: _resultados == null
              ? const SizedBox.shrink()
              : FutureBuilder<List<PerfilPublico>>(
                  future: _resultados,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text(mensajeDeError(snap.error!)));
                    }
                    final lista = (snap.data ?? const <PerfilPublico>[])
                        .where((p) => !p.esMenor)
                        .toList();
                    if (lista.isEmpty) {
                      return const Center(child: Text('No se encontró a nadie.'));
                    }
                    return ListView(children: [
                      for (final p in lista)
                        ListTile(
                          title: Text(p.nombre),
                          subtitle: Text(p.dojo),
                          onTap: () async {
                            final navegador = Navigator.of(context);
                            final si = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                content: Text(
                                    '¿Nombrar a ${p.nombre} como administrador? '
                                    'Podrá aprobar organizadores y nombrar a otros administradores.'),
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
                            if (si != true || !context.mounted) return;
                            await _hacer(
                                context,
                                () => AdminServicio().agregarAdmin(p.id, p.nombre),
                                '${p.nombre} ahora es administrador');
                            navegador.pop();
                          },
                        ),
                    ]);
                  },
                ),
        ),
      ]),
    );
  }
}

String _nombreTipo(String tipo) {
  switch (tipo) {
    case 'publicacion':
      return 'Publicación';
    case 'comentario':
      return 'Comentario';
  }
  return 'Perfil';
}

/// Pantalla 12: denuncias. Borrar el contenido, suspender a quien lo
/// publicó o descartar la denuncia.
class _Denuncias extends StatelessWidget {
  const _Denuncias();

  @override
  Widget build(BuildContext context) {
    final servicio = SocialServicio();
    return StreamBuilder(
      stream: servicio.denuncias(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(mensajeDeError(snap.error!)));
        final lista = snap.data;
        if (lista == null) return const Center(child: CircularProgressIndicator());
        if (lista.isEmpty) return const Center(child: Text('No hay denuncias.'));
        return ListView.separated(
          itemCount: lista.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = lista[i];
            final datos = d.data();
            final tipo = datos['tipo'] as String? ?? 'perfil';
            final ruta = datos['ruta'] as String? ?? '';
            final autorUid = datos['autorUid'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nombreTipo(tipo), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Contenido: "${datos['vistaPrevia'] ?? ''}"'),
                  const SizedBox(height: 4),
                  Text('Motivo: ${datos['motivo'] ?? ''}'),
                  Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
                    TextButton(
                      onPressed: () => Navegacion.abrirPerfil?.call(context, autorUid),
                      child: const Text('Ver autor'),
                    ),
                    TextButton(
                      onPressed: () => _hacer(context, () => servicio.descartarDenuncia(d.id),
                          'Denuncia descartada'),
                      child: const Text('Descartar'),
                    ),
                    if (tipo != 'perfil')
                      TextButton(
                        onPressed: () async {
                          if (!await _confirmar(context, '¿Borrar este contenido?') ||
                              !context.mounted) {
                            return;
                          }
                          await _hacer(context, () async {
                            await servicio.borrarDenunciado(ruta);
                            await servicio.descartarDenuncia(d.id);
                          }, 'Contenido borrado');
                        },
                        child: const Text('Borrar contenido'),
                      ),
                    FilledButton(
                      onPressed: () async {
                        if (!await _confirmar(context,
                                '¿Suspender la cuenta de quien publicó esto? No podrá publicar, '
                                'comentar ni enviar solicitudes.') ||
                            !context.mounted) {
                          return;
                        }
                        final perfil = await PerfilesServicio().verPublico(autorUid).first;
                        if (!context.mounted) return;
                        await _hacer(context,
                            () => servicio.suspender(autorUid, perfil?.nombre ?? ''),
                            'Cuenta suspendida');
                      },
                      child: const Text('Suspender cuenta'),
                    ),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Suspendidos extends StatelessWidget {
  const _Suspendidos();

  @override
  Widget build(BuildContext context) {
    final servicio = SocialServicio();
    return StreamBuilder(
      stream: servicio.suspendidos(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(mensajeDeError(snap.error!)));
        final lista = snap.data;
        if (lista == null) return const Center(child: CircularProgressIndicator());
        if (lista.isEmpty) return const Center(child: Text('No hay cuentas suspendidas.'));
        return ListView(children: [
          for (final d in lista)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(d.data()['nombre'] as String? ?? ''),
              onTap: () => Navegacion.abrirPerfil?.call(context, d.id),
              trailing: TextButton(
                onPressed: () => _hacer(context, () => servicio.quitarSuspension(d.id),
                    'Suspensión quitada'),
                child: const Text('Quitar suspensión'),
              ),
            ),
        ]);
      },
    );
  }
}
