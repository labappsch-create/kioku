import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import 'categorias_pantalla.dart';
import 'editar_competencia_pantalla.dart';
import 'inscribir_alumnos_pantalla.dart';
import 'inscribir_pantalla.dart';
import 'inscritos_pantalla.dart';

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
          Text(c.nombre, style: textos.headlineSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(nombreNivel(c.nivel))),
            Chip(label: Text(nombreEstado(estado))),
          ]),
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
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.groups),
                      label: const Text('Inscritos'),
                      onPressed: () => _abrir(
                          context,
                          InscritosPantalla(
                              competencia: c, uid: uid, comoOrganizador: true)),
                    ),
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
                    if (abiertas) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock),
                        label: const Text('Cerrar inscripciones antes'),
                        onPressed: () => _cerrarAntes(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
