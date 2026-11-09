import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../modelos/resultado.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/resultados_servicio.dart';

/// Pantallas 1 y 3: cargar resultados (organizador) o corregirlos
/// (administrador, después del plazo).
class CargarResultadosPantalla extends StatelessWidget {
  const CargarResultadosPantalla({
    super.key,
    required this.competencia,
    required this.uid,
    required this.comoAdmin,
  });

  final Competencia competencia;
  final String uid;
  final bool comoAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(comoAdmin ? 'Corregir resultados' : 'Cargar resultados')),
      body: StreamBuilder<List<Categoria>>(
        stream: CompetenciasServicio().categorias(competencia.id),
        builder: (context, cats) => StreamBuilder<List<Podio>>(
          stream: ResultadosServicio().deCompetencia(competencia.id),
          builder: (context, pods) {
            final error = cats.error ?? pods.error;
            if (error != null) {
              return Center(child: Text(mensajeDeError(error)));
            }
            final categorias = cats.data;
            final podios = pods.data;
            if (categorias == null || podios == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (categorias.isEmpty) {
              return const Center(child: Text('Esta competencia no tiene categorías.'));
            }
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  comoAdmin
                      ? 'Como administrador puedes corregir los resultados aunque ya pasó el plazo del organizador.'
                      : 'Puedes cargar y corregir resultados hasta el '
                          '${textoFecha(competencia.limiteResultados.subtract(const Duration(days: 1)))}.',
                ),
              ),
              for (final c in categorias)
                _FilaCategoria(
                  competencia: competencia,
                  categoria: c,
                  podios: [for (final p in podios) if (p.categoriaId == c.id) p],
                  uid: uid,
                  comoAdmin: comoAdmin,
                ),
            ]);
          },
        ),
      ),
    );
  }
}

class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({
    required this.competencia,
    required this.categoria,
    required this.podios,
    required this.uid,
    required this.comoAdmin,
  });

  final Competencia competencia;
  final Categoria categoria;
  final List<Podio> podios;
  final String uid;
  final bool comoAdmin;

  @override
  Widget build(BuildContext context) {
    podios.sort((a, b) => a.puesto.compareTo(b.puesto));
    return Column(children: [
      ListTile(
        title: Text(categoria.nombre),
        subtitle: Text(podios.isEmpty
            ? 'Sin resultados'
            : podios.map((p) => '${p.puesto}.º ${p.atletaNombre}').join('\n')),
        trailing: const Icon(Icons.edit),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _EditarPodioPantalla(
            competencia: competencia,
            categoria: categoria,
            actuales: {for (final p in podios) p.puesto: p.iid},
            uid: uid,
            comoAdmin: comoAdmin,
          ),
        )),
      ),
      const Divider(height: 1),
    ]);
  }
}

class _EditarPodioPantalla extends StatefulWidget {
  const _EditarPodioPantalla({
    required this.competencia,
    required this.categoria,
    required this.actuales,
    required this.uid,
    required this.comoAdmin,
  });

  final Competencia competencia;
  final Categoria categoria;

  /// Puesto → id de la inscripción que lo tiene hoy.
  final Map<int, String> actuales;
  final String uid;
  final bool comoAdmin;

  @override
  State<_EditarPodioPantalla> createState() => _EditarPodioPantallaState();
}

class _EditarPodioPantallaState extends State<_EditarPodioPantalla> {
  final _servicio = ResultadosServicio();
  late Future<List<Inscripcion>> _carga;
  final Map<int, String?> _elegidos = {};
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _elegidos.addAll(widget.actuales);
    _carga = _servicio.confirmados(
      widget.competencia.id,
      widget.categoria.id,
      organizadorUid: widget.comoAdmin ? null : widget.uid,
    );
  }

  Future<void> _guardar(List<Inscripcion> inscritos) async {
    final elegidos = [
      for (final p in [1, 2, 3, 4])
        if (_elegidos[p] != null) _elegidos[p]
    ];
    if (elegidos.toSet().length != elegidos.length) {
      setState(() => _error = 'Una misma persona no puede tener dos puestos.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final navegador = Navigator.of(context);
      final mensajes = ScaffoldMessenger.of(context);
      final porId = {for (final i in inscritos) i.id: i};
      await _servicio.guardarCategoria(
        competencia: widget.competencia,
        categoria: widget.categoria,
        elegidos: {
          for (final p in [1, 2, 3, 4])
            p: _elegidos[p] == null ? null : porId[_elegidos[p]],
        },
      );
      mensajes.showSnackBar(const SnackBar(content: Text('Resultados guardados')));
      navegador.pop();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puestos')),
      body: FutureBuilder<List<Inscripcion>>(
        future: _carga,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(mensajeDeError(snap.error!), textAlign: TextAlign.center),
              ),
            );
          }
          final inscritos = snap.data ?? const <Inscripcion>[];
          final ids = {for (final i in inscritos) i.id};
          // Si alguien ya no está confirmado, su puesto queda vacío.
          for (final p in [1, 2, 3, 4]) {
            if (_elegidos[p] != null && !ids.contains(_elegidos[p])) {
              _elegidos[p] = null;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.categoria.nombre,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (inscritos.isEmpty)
                const Text('No hay inscritos confirmados en esta categoría.')
              else
                const Text('Elige a quién va cada puesto. Deja vacío lo que no corresponda.'),
              const SizedBox(height: 12),
              for (final p in [1, 2, 3, 4]) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _elegidos[p],
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: '$p.º lugar', border: const OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— Vacío —')),
                    for (final i in inscritos)
                      DropdownMenuItem<String?>(
                        value: i.id,
                        child: Text('${i.atletaNombre} · ${i.dojoNombre}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _elegidos[p] = v),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _guardando ? null : () => _guardar(inscritos),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar puestos'),
              ),
            ],
          );
        },
      ),
    );
  }
}
