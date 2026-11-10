import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../modelos/publicacion.dart';
import '../../modelos/resultado.dart';
import '../../servicios/admin_servicio.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/resultados_servicio.dart';
import '../../servicios/sesion.dart';
import '../resultados/cargar_resultados_pantalla.dart';
import '../social/crear_publicacion_pantalla.dart';
import 'ocultar_torneo.dart';
import '../ver_perfil_pantalla.dart';
import 'categorias_pantalla.dart';
import 'editar_competencia_pantalla.dart';
import 'inscribir_alumnos_pantalla.dart';
import 'inscribir_pantalla.dart';
import 'inscritos_pantalla.dart';
import 'reactivar_pantalla.dart';

/// Pantalla 4: ver una competencia.
class VerCompetenciaPantalla extends StatelessWidget {
  const VerCompetenciaPantalla({
    super.key,
    required this.competenciaId,
    required this.uid,
    required this.perfil,
  });

  final String competenciaId;
  final String uid;
  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Competencia?>(
      stream: CompetenciasServicio().ver(competenciaId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(mensajeDeError(snap.error!))));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final c = snap.data;
        if (c == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Esta competencia no existe.')));
        }
        return _Contenido(competencia: c, uid: uid, perfil: perfil);
      },
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.competencia,
    required this.uid,
    required this.perfil,
  });

  final Competencia competencia;
  final String uid;
  final Perfil perfil;

  void _abrir(BuildContext context, Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  Future<void> _cerrarAntes(BuildContext context) async {
    final mensajes = ScaffoldMessenger.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
            '¿Cerrar las inscripciones ahora? Ya nadie podrá inscribirse. '
            'Esto no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Cerrar inscripciones')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await CompetenciasServicio().cerrarInscripciones(competencia.id);
      mensajes.showSnackBar(
          const SnackBar(content: Text('Inscripciones cerradas')));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  /// Pide el motivo (obligatorio). Devuelve null si se cancela.
  Future<String?> _pedirMotivo(
      BuildContext context, String titulo, String explicacion, String boton) {
    final texto = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(titulo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(explicacion),
              const SizedBox(height: 12),
              TextField(
                controller: texto,
                autofocus: true,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo (obligatorio)',
                  helperText: 'Los inscritos y sus senseis lo verán en un aviso.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Volver')),
            FilledButton(
              onPressed: texto.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(texto.text.trim()),
              child: Text(boton),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _suspender(BuildContext context) async {
    final mensajes = ScaffoldMessenger.of(context);
    final motivo = await _pedirMotivo(
      context,
      'Suspender torneo',
      'El torneo queda en pausa. Las inscripciones se mantienen y nadie '
          'puede inscribirse ni anular. Después lo reactivas con fechas nuevas.',
      'Suspender',
    );
    if (motivo == null) return;
    try {
      await CompetenciasServicio().suspender(competencia, motivo);
      mensajes.showSnackBar(const SnackBar(content: Text('Torneo suspendido')));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _borrar(BuildContext context) async {
    final navegador = Navigator.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar torneo'),
        content: const Text(
            'Se borrará para todos: el torneo, sus categorías y sus inscripciones. '
            'Esto no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Volver')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await CompetenciasServicio().borrarTorneo(competencia, uid);
      mensajes.showSnackBar(const SnackBar(content: Text('Torneo borrado')));
      navegador.pop();
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _cancelar(BuildContext context) async {
    final mensajes = ScaffoldMessenger.of(context);
    final motivo = await _pedirMotivo(
      context,
      'Cancelar torneo',
      'Es definitivo: el torneo no se hará y no se puede deshacer. '
          'Las inscripciones se mantienen marcadas como "Torneo cancelado".',
      'Cancelar torneo',
    );
    if (motivo == null) return;
    try {
      await CompetenciasServicio().cancelar(competencia, motivo);
      mensajes.showSnackBar(const SnackBar(content: Text('Torneo cancelado')));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = competencia;
    final textos = Theme.of(context).textTheme;
    final estado = c.estado(DateTime.now());
    final abiertas = estado == EstadoCompetencia.abiertas;
    final esOrganizador = c.organizadorUid == uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Competencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (c.aficheUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(c.aficheUrl!, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            const SizedBox(height: 12),
          ],
          Text(c.nombre, style: textos.headlineSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(nombreNivel(c.nivel))),
            Chip(label: Text(nombreEstado(estado))),
          ]),
          const SizedBox(height: 8),
          if (c.cancelada || c.suspendida)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${c.cancelada ? 'Torneo cancelado' : 'Torneo suspendido (postergado)'}'
                  '\nMotivo: ${c.motivo ?? ''}',
                ),
              ),
            )
          else if (c.avisoTexto != null)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Aviso del organizador:\n${c.avisoTexto}'),
              ),
            ),
          const SizedBox(height: 8),
          if (esOrganizador) ...[
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Eres el organizador de esta competencia.'),
                    if (c.organizadorPuedeCargar(DateTime.now())) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.emoji_events),
                        label: const Text('Cargar resultados'),
                        onPressed: () => _abrir(
                            context,
                            CargarResultadosPantalla(
                                competencia: c, uid: uid, comoAdmin: false)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.groups),
                      label: const Text('Inscritos'),
                      onPressed: () => _abrir(
                          context,
                          InscritosPantalla(
                              competencia: c, uid: uid, comoOrganizador: true)),
                    ),
                    if (!c.cancelada) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.category),
                        label: const Text('Categorías'),
                        onPressed: () =>
                            _abrir(context, CategoriasPantalla(competencia: c)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar competencia'),
                        onPressed: () => _abrir(
                            context,
                            EditarCompetenciaPantalla(
                                uid: uid, perfil: perfil, competencia: c)),
                      ),
                    ],
                    if (abiertas) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock),
                        label: const Text('Cerrar inscripciones antes'),
                        onPressed: () => _cerrarAntes(context),
                      ),
                    ],
                    if (c.suspendida) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reactivar con fechas nuevas'),
                        onPressed: () =>
                            _abrir(context, ReactivarPantalla(competencia: c)),
                      ),
                    ],
                    if (!c.cancelada &&
                        !c.suspendida &&
                        estado != EstadoCompetencia.finalizada) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.pause),
                        label: const Text('Suspender (postergar)'),
                        onPressed: () => _suspender(context),
                      ),
                    ],
                    if (!c.cancelada &&
                        estado != EstadoCompetencia.finalizada) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar torneo'),
                        onPressed: () => _cancelar(context),
                      ),
                    ],
                    if (c.cancelada) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Borrar torneo'),
                        onPressed: () => _borrar(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (sePuedeOcultar(c))
            ValueListenableBuilder<int>(
              valueListenable: Sesion.cambios,
              builder: (context, _, __) {
                final oculto = estaOculto(c.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    icon: Icon(oculto ? Icons.visibility : Icons.visibility_off),
                    label: Text(oculto ? 'Mostrar de nuevo en mis listas' : 'Ocultar de mis listas'),
                    onPressed: () => cambiarOculto(context, c, ocultar: !oculto),
                  ),
                );
              },
            ),
          if (!c.cancelada)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartir en el muro'),
                onPressed: () => _abrir(
                  context,
                  CrearPublicacionPantalla(
                    torneo: TorneoCompartido(
                      id: c.id,
                      nombre: c.nombre,
                      fechas: c.textoFechas,
                      lugar: c.lugar,
                      nivel: c.nivel,
                    ),
                  ),
                ),
              ),
            ),
          if (abiertas)
            FilledButton.icon(
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Inscribirme'),
              onPressed: () => _abrir(context,
                  InscribirmePantalla(competencia: c, uid: uid, perfil: perfil)),
            ),
          StreamBuilder<List<DojoPublico>>(
            stream: DojosServicio().misDojos(uid),
            builder: (context, snap) {
              if ((snap.data ?? const []).isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (abiertas) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Inscribir a mis alumnos'),
                      onPressed: () => _abrir(context,
                          InscribirAlumnosPantalla(competencia: c, uid: uid)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.groups),
                    label: const Text('Inscritos de mis dojos'),
                    onPressed: () => _abrir(
                        context,
                        InscritosPantalla(
                            competencia: c, uid: uid, comoOrganizador: false)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _Fila(icono: Icons.event, titulo: 'Fechas', valor: c.textoFechas),
          _Fila(
              icono: Icons.event_busy,
              titulo: 'Inscripciones hasta',
              valor: c.cerradaAntes
                  ? 'Cerradas por el organizador'
                  : textoFecha(c.fechaLimite)),
          _Fila(icono: Icons.person, titulo: 'Organiza', valor: c.organiza),
          _Fila(icono: Icons.place, titulo: 'Lugar', valor: c.lugar),
          _Fila(icono: Icons.map, titulo: 'Dirección', valor: c.direccion),
          _Fila(
              icono: Icons.sports_martial_arts,
              titulo: 'Modalidades',
              valor: c.modalidadesElegidas.map(nombreModalidad).join(' y ')),
          if (c.costo != null)
            _Fila(icono: Icons.payments, titulo: 'Costo', valor: c.costo!),
          _Fila(icono: Icons.call, titulo: 'Contacto', valor: c.contacto),
          const SizedBox(height: 12),
          Text('Descripción y bases', style: textos.titleSmall),
          const SizedBox(height: 4),
          Text(c.descripcion),
          if (c.reglamento != null) ...[
            const SizedBox(height: 12),
            Text('Reglamento', style: textos.titleSmall),
            const SizedBox(height: 4),
            SelectableText(c.reglamento!),
          ],
          if (c.resultadosEmpezaron(DateTime.now()) &&
              !c.organizadorPuedeCargar(DateTime.now()))
            StreamBuilder<bool>(
              stream: AdminServicio()
                  .esAdmin(uid, FirebaseAuth.instance.currentUser?.email),
              builder: (context, snap) => snap.data == true
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Corregir resultados (administrador)'),
                        onPressed: () => _abrir(
                            context,
                            CargarResultadosPantalla(
                                competencia: c, uid: uid, comoAdmin: true)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          _Resultados(competencia: c),
          const SizedBox(height: 16),
          Text('Categorías', style: textos.titleSmall),
          const SizedBox(height: 4),
          StreamBuilder<List<Categoria>>(
            stream: CompetenciasServicio().categorias(c.id),
            builder: (context, snap) {
              if (snap.hasError) return Text(mensajeDeError(snap.error!));
              final lista = snap.data;
              if (lista == null) return const LinearProgressIndicator();
              if (lista.isEmpty) {
                return Text(esOrganizador
                    ? 'Aún no hay categorías. Toca "Categorías" para agregarlas.'
                    : 'Aún no hay categorías.');
              }
              return Column(children: [
                for (final cat in lista)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(cat.nombre),
                    trailing: Text('${cat.inscritos} inscritos'),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Pantalla 2: podio de cada categoría, visible para todos.
class _Resultados extends StatelessWidget {
  const _Resultados({required this.competencia});

  final Competencia competencia;

  @override
  Widget build(BuildContext context) {
    if (competencia.cancelada) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    return StreamBuilder<List<Podio>>(
      stream: ResultadosServicio().deCompetencia(competencia.id),
      builder: (context, snap) {
        final podios = snap.data;
        if (snap.hasError || podios == null || podios.isEmpty) {
          return const SizedBox.shrink();
        }
        final porCategoria = <String, List<Podio>>{};
        for (final p in podios) {
          porCategoria.putIfAbsent(p.categoriaNombre, () => []).add(p);
        }
        final nombres = porCategoria.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Resultados', style: textos.titleSmall),
            for (final n in nombres) ...[
              const SizedBox(height: 8),
              Text(n, style: textos.labelLarge),
              for (final p in porCategoria[n]!
                ..sort((a, b) => a.puesto.compareTo(b.puesto)))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 14, child: Text('${p.puesto}')),
                  title: Text(p.atletaNombre),
                  subtitle: Text(p.dojoNombre),
                  trailing: Text('${p.puntos} pts'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VerPerfilPantalla(uid: p.atletaUid))),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.labelSmall),
                Text(valor, style: textos.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
