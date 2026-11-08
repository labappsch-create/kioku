import 'package:flutter/material.dart';

import '../../datos/grados.dart';
import '../../modelos/competencia.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';

/// Pantalla 6: crear o editar categorías (solo el organizador).
class CategoriasPantalla extends StatelessWidget {
  const CategoriasPantalla({super.key, required this.competencia});

  final Competencia competencia;

  Future<void> _editar(BuildContext context, [Categoria? actual]) async {
    final mensajes = ScaffoldMessenger.of(context);
    final cat = await showDialog<Categoria>(
      context: context,
      builder: (_) => _DialogoCategoria(
          modalidades: competencia.modalidadesElegidas, inicial: actual),
    );
    if (cat == null) return;
    try {
      await CompetenciasServicio().guardarCategoria(competencia.id, cat);
      mensajes.showSnackBar(const SnackBar(content: Text('Categoría guardada')));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _borrar(BuildContext context, Categoria c) async {
    final mensajes = ScaffoldMessenger.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('¿Borrar la categoría "${c.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await CompetenciasServicio().borrarCategoria(competencia.id, c.id);
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar categoría'),
        onPressed: () => _editar(context),
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: CompetenciasServicio().categorias(competencia.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final lista = snap.data;
          if (lista == null) return const Center(child: CircularProgressIndicator());
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay categorías.\nToca "Agregar categoría" para crear la primera.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = lista[i];
              return ListTile(
                title: Text(c.nombre),
                subtitle: Text('${c.inscritos} inscritos'),
                onTap: () => _editar(context, c),
                trailing: IconButton(
                  tooltip: c.inscritos == 0
                      ? 'Borrar'
                      : 'No se puede borrar: tiene inscritos',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: c.inscritos == 0 ? () => _borrar(context, c) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DialogoCategoria extends StatefulWidget {
  const _DialogoCategoria({required this.modalidades, this.inicial});

  final List<String> modalidades;
  final Categoria? inicial;

  @override
  State<_DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends State<_DialogoCategoria> {
  late String _modalidad;
  String? _sexo;
  late final TextEditingController _edadMin;
  late final TextEditingController _edadMax;
  late final TextEditingController _pesoMin;
  late final TextEditingController _pesoMax;
  String? _gradoMin;
  String? _gradoMax;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.inicial;
    _modalidad = c?.modalidad ??
        (widget.modalidades.isEmpty ? modalidadKumite : widget.modalidades.first);
    // Una categoría antigua "Mixto" obliga a elegir de nuevo.
    _sexo = sexosCategoria.contains(c?.sexo) ? c!.sexo : null;
    _edadMin = TextEditingController(text: c?.edadMin?.toString() ?? '');
    _edadMax = TextEditingController(text: c?.edadMax?.toString() ?? '');
    _pesoMin = TextEditingController(
        text: c?.pesoMin == null ? '' : textoNumero(c!.pesoMin!));
    _pesoMax = TextEditingController(
        text: c?.pesoMax == null ? '' : textoNumero(c!.pesoMax!));
    _gradoMin = c?.gradoMinId;
    _gradoMax = c?.gradoMaxId;
  }

  @override
  void dispose() {
    for (final t in [_edadMin, _edadMax, _pesoMin, _pesoMax]) {
      t.dispose();
    }
    super.dispose();
  }

  num? _numero(TextEditingController t) {
    final v = t.text.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return num.tryParse(v);
  }

  bool _invalido(TextEditingController t) =>
      t.text.trim().isNotEmpty && _numero(t) == null;

  Categoria? _armar() {
    if (_sexo == null) {
      _error = 'Elige el sexo de la categoría.';
      return null;
    }
    if ([_edadMin, _edadMax, _pesoMin, _pesoMax].any(_invalido)) {
      _error = 'Revisa los números: solo dígitos (o déjalos vacíos).';
      return null;
    }
    final eMin = _numero(_edadMin)?.round();
    final eMax = _numero(_edadMax)?.round();
    final pMin = _numero(_pesoMin)?.toDouble();
    final pMax = _numero(_pesoMax)?.toDouble();
    if (eMin != null && eMax != null && eMin > eMax) {
      _error = 'La edad mínima no puede ser mayor que la máxima.';
      return null;
    }
    if (pMin != null && pMax != null && pMin > pMax) {
      _error = 'El peso mínimo no puede ser mayor que el máximo.';
      return null;
    }
    if (_gradoMin != null &&
        _gradoMax != null &&
        indiceGrado(_gradoMin) > indiceGrado(_gradoMax)) {
      _error = 'El grado "desde" no puede ser mayor que el grado "hasta".';
      return null;
    }
    _error = null;
    return Categoria(
      id: widget.inicial?.id ?? '',
      modalidad: _modalidad,
      sexo: _sexo!,
      edadMin: eMin,
      edadMax: eMax,
      pesoMin: pMin,
      pesoMax: pMax,
      gradoMinId: _gradoMin,
      gradoMaxId: _gradoMax,
      inscritos: widget.inicial?.inscritos ?? 0,
    );
  }

  Widget _par(String titulo, TextEditingController a, TextEditingController b,
      String unidad, {bool decimal = false}) {
    final teclado = decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: a,
          keyboardType: teclado,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: '$titulo desde',
              suffixText: unidad,
              border: const OutlineInputBorder()),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: b,
          keyboardType: teclado,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: 'hasta',
              suffixText: unidad,
              border: const OutlineInputBorder()),
        ),
      ),
    ]);
  }

  DropdownButtonFormField<String?> _grado(
      String titulo, String? valor, ValueChanged<String?> alCambiar) {
    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      decoration:
          InputDecoration(labelText: titulo, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Cualquiera')),
        for (final g in grados)
          DropdownMenuItem<String?>(
              value: g.id, child: Text(g.descripcion, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => setState(() => alCambiar(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borde = OutlineInputBorder();
    const espacio = SizedBox(height: 12);
    final vista = _armar();
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _modalidad,
              decoration: const InputDecoration(labelText: 'Modalidad', border: borde),
              items: [
                for (final m in widget.modalidades)
                  DropdownMenuItem(value: m, child: Text(nombreModalidad(m))),
              ],
              onChanged: (v) => setState(() => _modalidad = v ?? _modalidad),
            ),
            espacio,
            DropdownButtonFormField<String>(
              initialValue: _sexo,
              decoration: const InputDecoration(labelText: 'Sexo', border: borde),
              items: [
                for (final s in sexosCategoria)
                  DropdownMenuItem(value: s, child: Text(nombreSexoCategoria(s))),
              ],
              onChanged: (v) => setState(() => _sexo = v),
            ),
            espacio,
            const Text('Deja vacío lo que no tenga límite.',
                style: TextStyle(fontSize: 12)),
            espacio,
            _par('Edad', _edadMin, _edadMax, 'años'),
            espacio,
            _par('Peso', _pesoMin, _pesoMax, 'kg', decimal: true),
            espacio,
            _grado('Grado desde', _gradoMin, (v) => _gradoMin = v),
            espacio,
            _grado('Grado hasta', _gradoMax, (v) => _gradoMax = v),
            espacio,
            if (vista != null)
              Text('Quedará así: ${vista.nombre}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: vista == null ? null : () => Navigator.of(context).pop(vista),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
