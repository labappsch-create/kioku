import 'package:flutter/material.dart';

import '../../datos/lugares.dart';
import '../../datos/puntos.dart';
import '../../modelos/competencia.dart';
import '../../modelos/resultado.dart';
import '../../servicios/errores.dart';
import '../../servicios/resultados_servicio.dart';
import '../dojos/ver_dojo_pantalla.dart';
import '../ver_perfil_pantalla.dart';

/// Pantalla 4: rankings (pestaña "Rankings").
class RankingsPantalla extends StatefulWidget {
  const RankingsPantalla({super.key, required this.paisInicial});

  /// País del perfil, para proponerlo en el filtro.
  final String paisInicial;

  @override
  State<RankingsPantalla> createState() => _RankingsPantallaState();
}

class _RankingsPantallaState extends State<RankingsPantalla> {
  final _servicio = ResultadosServicio();

  late int _anio;
  Alcance _alcance = Alcance.pais;
  String? _pais;
  String? _region;
  bool _dojos = false;
  String _modalidad = modalidadKumite;
  String _sexo = sexoMasculino;
  String _grupo = 'adultos';

  /// Para dojos: null = total general.
  String? _modalidadDojo;

  Future<List<FilaRanking>>? _resultado;
  String _titulo = '';

  @override
  void initState() {
    super.initState();
    _anio = DateTime.now().year;
    _pais = paisPorNombre(widget.paisInicial)?.nombre;
    if (_pais == null) _alcance = Alcance.latinoamerica;
    _ver();
  }

  String? get _faltaFiltro {
    if (_alcance != Alcance.latinoamerica && _pais == null) return 'Elige el país.';
    if (_alcance == Alcance.region && _region == null) {
      return 'Elige la ${paisPorNombre(_pais)?.tipoRegion.toLowerCase() ?? 'región'}.';
    }
    return null;
  }

  void _ver() {
    if (_faltaFiltro != null) {
      setState(() => _resultado = null);
      return;
    }
    final lugar = switch (_alcance) {
      Alcance.latinoamerica => 'Latinoamérica',
      Alcance.pais => _pais!,
      Alcance.region => '$_region, $_pais',
    };
    setState(() {
      if (_dojos) {
        _titulo = 'Dojos · ${_modalidadDojo == null ? 'Total' : nombreModalidad(_modalidadDojo!)}'
            ' · $lugar $_anio';
        _resultado = _servicio.rankingDojos(
          anio: _anio,
          alcance: _alcance,
          pais: _pais,
          region: _region,
          modalidad: _modalidadDojo,
        );
      } else {
        _titulo = '${nombreModalidad(_modalidad)} ${nombreSexoCategoria(_sexo).toLowerCase()}'
            ' · ${nombreGrupo(_grupo)} · $lugar $_anio';
        _resultado = _servicio.rankingAtletas(
          anio: _anio,
          alcance: _alcance,
          pais: _pais,
          region: _region,
          modalidad: _modalidad,
          sexo: _sexo,
          grupo: _grupo,
        );
      }
    });
  }

  Widget _filtros() {
    const borde = OutlineInputBorder();
    const espacio = SizedBox(height: 8);
    final pais = paisPorNombre(_pais);
    final hoy = DateTime.now().year;

    Widget fila(Widget a, Widget b) => Row(children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
        ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Atletas'), icon: Icon(Icons.person)),
            ButtonSegment(
                value: true, label: Text('Dojos'), icon: Icon(Icons.sports_martial_arts)),
          ],
          selected: {_dojos},
          onSelectionChanged: (v) => setState(() => _dojos = v.first),
        ),
        espacio,
        fila(
          DropdownButtonFormField<int>(
            initialValue: _anio,
            decoration: const InputDecoration(labelText: 'Año', border: borde),
            items: [
              for (var a = hoy; a >= hoy - 4; a--)
                DropdownMenuItem(value: a, child: Text('$a')),
            ],
            onChanged: (v) => setState(() => _anio = v ?? _anio),
          ),
          DropdownButtonFormField<Alcance>(
            initialValue: _alcance,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Alcance', border: borde),
            items: const [
              DropdownMenuItem(value: Alcance.latinoamerica, child: Text('Latinoamérica')),
              DropdownMenuItem(value: Alcance.pais, child: Text('País')),
              DropdownMenuItem(value: Alcance.region, child: Text('Región')),
            ],
            onChanged: (v) => setState(() => _alcance = v ?? _alcance),
          ),
        ),
        if (_alcance != Alcance.latinoamerica) ...[
          espacio,
          DropdownButtonFormField<String>(
            initialValue: _pais,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'País', border: borde),
            items: [
              for (final p in paises)
                DropdownMenuItem(value: p.nombre, child: Text(p.nombre)),
            ],
            onChanged: (v) => setState(() {
              _pais = v;
              _region = null;
            }),
          ),
        ],
        if (_alcance == Alcance.region) ...[
          espacio,
          DropdownButtonFormField<String>(
            key: ValueKey('rk-region-$_pais'),
            initialValue: _region,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: pais?.tipoRegion ?? 'Región',
              helperText: pais == null ? 'Primero elige el país' : null,
              border: borde,
            ),
            items: [
              for (final r in pais?.regiones ?? const <String>[])
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: pais == null ? null : (v) => setState(() => _region = v),
          ),
        ],
        espacio,
        if (_dojos)
          DropdownButtonFormField<String?>(
            initialValue: _modalidadDojo,
            decoration: const InputDecoration(labelText: 'Ranking', border: borde),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Total general')),
              for (final m in modalidades)
                DropdownMenuItem<String?>(value: m, child: Text(nombreModalidad(m))),
            ],
            onChanged: (v) => setState(() => _modalidadDojo = v),
          )
        else ...[
          fila(
            DropdownButtonFormField<String>(
              initialValue: _modalidad,
              decoration: const InputDecoration(labelText: 'Modalidad', border: borde),
              items: [
                for (final m in modalidades)
                  DropdownMenuItem(value: m, child: Text(nombreModalidad(m))),
              ],
              onChanged: (v) => setState(() => _modalidad = v ?? _modalidad),
            ),
            DropdownButtonFormField<String>(
              initialValue: _sexo,
              decoration: const InputDecoration(labelText: 'Sexo', border: borde),
              items: [
                for (final s in sexosCategoria)
                  DropdownMenuItem(value: s, child: Text(nombreSexoCategoria(s))),
              ],
              onChanged: (v) => setState(() => _sexo = v ?? _sexo),
            ),
          ),
          espacio,
          DropdownButtonFormField<String>(
            initialValue: _grupo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Grupo de edad', border: borde),
            items: [
              for (final g in gruposEdad)
                DropdownMenuItem(value: g.id, child: Text('${g.nombre} (${g.edades})')),
            ],
            onChanged: (v) => setState(() => _grupo = v ?? _grupo),
          ),
        ],
        espacio,
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.leaderboard),
            label: const Text('Ver ranking'),
            onPressed: _ver,
          ),
        ),
      ]),
    );
  }

  Widget _lista() {
    final falta = _faltaFiltro;
    if (_resultado == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(falta ?? 'Elige los filtros y toca "Ver ranking".',
            textAlign: TextAlign.center),
      );
    }
    return FutureBuilder<List<FilaRanking>>(
      future: _resultado,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(mensajeDeError(snap.error!), textAlign: TextAlign.center),
          );
        }
        final filas = snap.data ?? const <FilaRanking>[];
        final textos = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(_titulo, style: textos.titleSmall),
            ),
            if (filas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no hay resultados para este ranking.',
                    textAlign: TextAlign.center),
              ),
            for (var i = 0; i < filas.length; i++)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(filas[i].nombre),
                subtitle: Text([
                  if (filas[i].detalle.isNotEmpty) filas[i].detalle,
                  filas[i].resumenPuestos,
                ].join('\n')),
                trailing: Text('${filas[i].puntos} pts', style: textos.titleSmall),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _dojos
                      ? VerDojoPantalla(dojoId: filas[i].id)
                      : VerPerfilPantalla(uid: filas[i].id),
                )),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
        actions: [
          IconButton(
            tooltip: 'Tabla de puntos',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TablaPuntosPantalla())),
          ),
        ],
      ),
      body: ListView(children: [
        _filtros(),
        const Divider(),
        _lista(),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Pantalla 5: cómo se calculan los puntos.
class TablaPuntosPantalla extends StatelessWidget {
  const TablaPuntosPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tabla de puntos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Cada puesto da puntos según el nivel del torneo. El ranking suma '
            'los puntos del año calendario. Si hay empate, gana quien tiene más '
            '1.º lugares; luego más 2.º, y así.',
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: [
                const DataColumn(label: Text('Puesto')),
                for (final n in niveles) DataColumn(label: Text(nombreNivel(n)), numeric: true),
              ],
              rows: [
                for (final p in puestos)
                  DataRow(cells: [
                    DataCell(Text('$p.º')),
                    for (final n in niveles) DataCell(Text('${puntosDe(n, p)}')),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Grupos de edad', style: textos.titleSmall),
          const SizedBox(height: 4),
          const Text('Se usa la edad que tenía el atleta al inscribirse en el torneo.'),
          const SizedBox(height: 8),
          for (final g in gruposEdad) Text('• ${g.nombre}: ${g.edades}'),
          const SizedBox(height: 24),
          Text('Alcance', style: textos.titleSmall),
          const SizedBox(height: 4),
          const Text(
            'Los rankings de país y región cuentan los torneos que se hicieron '
            'en ese lugar. El de Latinoamérica cuenta todos.',
          ),
          const SizedBox(height: 24),
          Text('Dojos', style: textos.titleSmall),
          const SizedBox(height: 4),
          const Text(
            'Cada dojo suma los puntos de sus atletas, según el dojo con que '
            'se inscribieron en cada torneo.',
          ),
        ],
      ),
    );
  }
}
