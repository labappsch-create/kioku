import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../datos/lugares.dart';
import '../../modelos/competencia.dart';
import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../servicios/admin_servicio.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import 'ver_competencia_pantalla.dart';

/// Pantalla 5: crear o editar una competencia.
///
/// - Locales: el sensei de un dojo, a nombre de ese dojo.
/// - Regionales, nacionales e internacionales: organizadores aprobados.
class EditarCompetenciaPantalla extends StatelessWidget {
  const EditarCompetenciaPantalla({
    super.key,
    required this.uid,
    required this.perfil,
    this.competencia,
  });

  final String uid;
  final Perfil perfil;

  /// Null al crear una nueva.
  final Competencia? competencia;

  @override
  Widget build(BuildContext context) {
    if (competencia != null) {
      return _Formulario(
        uid: uid,
        perfil: perfil,
        competencia: competencia,
        nivelesPermitidos: [competencia!.nivel],
        dojos: const [],
      );
    }
    return StreamBuilder<List<DojoPublico>>(
      stream: DojosServicio().misDojos(uid),
      builder: (context, dojos) => StreamBuilder<bool>(
        stream: AdminServicio().esOrganizador(uid),
        builder: (context, org) {
          final error = dojos.error ?? org.error;
          if (error != null) {
            return Scaffold(
                appBar: AppBar(title: const Text('Crear competencia')),
                body: Center(child: Text(mensajeDeError(error))));
          }
          if (!dojos.hasData || !org.hasData) {
            return Scaffold(
                appBar: AppBar(title: const Text('Crear competencia')),
                body: const Center(child: CircularProgressIndicator()));
          }
          final permitidos = [
            if (dojos.data!.isNotEmpty) nivelLocal,
            if (org.data!) ...nivelesOrganizador,
          ];
          if (permitidos.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Crear competencia')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Para crear un torneo local necesitas tener un dojo en Kioku '
                    '(pestaña Dojos → Mis dojos).\n\n'
                    'Para torneos regionales, nacionales o internacionales '
                    'necesitas ser organizador aprobado '
                    '(Competencias → menú 🏆 → Ser organizador).',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return _Formulario(
            uid: uid,
            perfil: perfil,
            nivelesPermitidos: permitidos,
            dojos: dojos.data!,
          );
        },
      ),
    );
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario({
    required this.uid,
    required this.perfil,
    required this.nivelesPermitidos,
    required this.dojos,
    this.competencia,
  });

  final String uid;
  final Perfil perfil;
  final List<String> nivelesPermitidos;
  final List<DojoPublico> dojos;
  final Competencia? competencia;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _form = GlobalKey<FormState>();
  final _servicio = CompetenciasServicio();

  late final TextEditingController _nombre;
  late final TextEditingController _ciudad;
  late final TextEditingController _direccion;
  late final TextEditingController _descripcion;
  late final TextEditingController _costo;
  late final TextEditingController _contacto;
  late final TextEditingController _reglamento;

  String? _nivel;
  String? _dojoId;
  DateTime? _inicio;
  DateTime? _fin;
  DateTime? _limite;
  String? _pais;
  String? _region;
  final Set<String> _modalidades = {};

  bool _guardando = false;
  String? _error;

  bool get _editando => widget.competencia != null;

  @override
  void initState() {
    super.initState();
    final c = widget.competencia;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _ciudad = TextEditingController(text: c?.ciudad ?? widget.perfil.ciudad);
    _direccion = TextEditingController(text: c?.direccion ?? '');
    _descripcion = TextEditingController(text: c?.descripcion ?? '');
    _costo = TextEditingController(text: c?.costo ?? '');
    _contacto = TextEditingController(text: c?.contacto ?? '');
    _reglamento = TextEditingController(text: c?.reglamento ?? '');
    if (c != null) {
      _nivel = c.nivel;
      _dojoId = c.dojoId;
      _inicio = c.fechaInicio;
      _fin = c.fechaFin;
      _limite = c.fechaLimite;
      _modalidades.addAll(c.modalidadesElegidas);
    } else {
      if (widget.nivelesPermitidos.length == 1) {
        _nivel = widget.nivelesPermitidos.first;
      }
      if (widget.dojos.length == 1) _dojoId = widget.dojos.first.id;
    }
    final paisInicial = c?.pais ?? widget.perfil.pais;
    final regionInicial = c?.region ?? widget.perfil.region;
    _pais = paisPorNombre(paisInicial)?.nombre;
    if (_pais != null && paisPorNombre(_pais)!.regiones.contains(regionInicial)) {
      _region = regionInicial;
    }
  }

  @override
  void dispose() {
    for (final t in [
      _nombre, _ciudad, _direccion, _descripcion, _costo, _contacto, _reglamento,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  String? _opcional(TextEditingController t) {
    final v = t.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<DateTime?> _elegirFecha(DateTime? actual, String ayuda) {
    final hoy = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: actual ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 3),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: ayuda,
    );
  }

  Widget _campoFecha(String titulo, DateTime? valor, ValueChanged<DateTime> alElegir) {
    return InkWell(
      onTap: () async {
        final f = await _elegirFecha(valor, titulo);
        if (f != null) setState(() => alElegir(soloDia(f)));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: titulo,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(valor == null ? 'Tocar para elegir' : textoFecha(valor)),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    final valido = _form.currentState!.validate();
    String? problema;
    if (_inicio == null || _fin == null || _limite == null) {
      problema = 'Faltan fechas: inicio, término y límite de inscripción.';
    } else if (_fin!.isBefore(_inicio!)) {
      problema = 'La fecha de término no puede ser antes del inicio.';
    } else if (_limite!.isAfter(_fin!)) {
      problema = 'La fecha límite de inscripción no puede ser después del término.';
    } else if (_modalidades.isEmpty) {
      problema = 'Elige al menos una modalidad.';
    } else if (!valido) {
      problema = 'Revisa los datos marcados en rojo.';
    }
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }

    final esLocal = _nivel == nivelLocal;
    String? dojoNombre;
    if (esLocal) {
      dojoNombre = _editando
          ? widget.competencia!.dojoNombre
          : widget.dojos.firstWhere((d) => d.id == _dojoId).nombre;
    }

    final datos = <String, Object?>{
      'nombre': _nombre.text.trim(),
      'nivel': _nivel,
      'organizadorUid': widget.uid,
      'organizadorNombre': widget.perfil.nombrePublico(DateTime.now()),
      'dojoId': esLocal ? _dojoId : null,
      'dojoNombre': dojoNombre,
      'fechaInicio': Timestamp.fromDate(_inicio!),
      'fechaFin': Timestamp.fromDate(_fin!),
      'fechaLimite': Timestamp.fromDate(_limite!),
      // Las inscripciones se cierran al terminar el día límite.
      'cierre': Timestamp.fromDate(diaSiguiente(_limite!)),
      'pais': _pais,
      'region': _region,
      'ciudad': _ciudad.text.trim(),
      'direccion': _direccion.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'modalidades': [for (final m in modalidades) if (_modalidades.contains(m)) m],
      'costo': _opcional(_costo),
      'contacto': _contacto.text.trim(),
      'reglamento': _opcional(_reglamento),
      'actualizado': FieldValue.serverTimestamp(),
    };

    setState(() => _guardando = true);
    try {
      final navegador = Navigator.of(context);
      final mensajes = ScaffoldMessenger.of(context);
      if (_editando) {
        await _servicio.actualizar(widget.competencia!.id, datos);
        mensajes.showSnackBar(const SnackBar(content: Text('Competencia guardada')));
        navegador.pop();
      } else {
        final id = await _servicio.crear(datos);
        mensajes.showSnackBar(const SnackBar(
            content: Text('Competencia creada. Ahora agrega sus categorías.')));
        navegador.pushReplacement(MaterialPageRoute(
            builder: (_) => VerCompetenciaPantalla(
                competenciaId: id, uid: widget.uid, perfil: widget.perfil)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pais = paisPorNombre(_pais);
    final textos = Theme.of(context).textTheme;
    const espacio = SizedBox(height: 12);
    const borde = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
          title: Text(_editando ? 'Editar competencia' : 'Crear competencia')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Datos obligatorios', style: textos.titleMedium),
              espacio,
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nombre de la competencia', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              if (_editando)
                InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Nivel', border: borde,
                      helperText: 'El nivel no se puede cambiar.'),
                  child: Text(nombreNivel(_nivel ?? nivelLocal)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _nivel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nivel', border: borde),
                  items: [
                    for (final n in widget.nivelesPermitidos)
                      DropdownMenuItem(value: n, child: Text(nombreNivel(n))),
                  ],
                  onChanged: (v) => setState(() => _nivel = v),
                  validator: (v) => v == null ? 'Elige el nivel' : null,
                ),
              if (_nivel == nivelLocal) ...[
                espacio,
                if (_editando)
                  InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Dojo organizador', border: borde),
                    child: Text(widget.competencia!.dojoNombre ?? ''),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _dojoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Dojo organizador', border: borde),
                    items: [
                      for (final d in widget.dojos)
                        DropdownMenuItem(value: d.id, child: Text(d.nombre)),
                    ],
                    onChanged: (v) => setState(() => _dojoId = v),
                    validator: (v) => v == null ? 'Elige el dojo' : null,
                  ),
              ],
              espacio,
              _campoFecha('Primer día del evento', _inicio, (f) => _inicio = f),
              espacio,
              _campoFecha('Último día del evento', _fin, (f) => _fin = f),
              espacio,
              _campoFecha('Fecha límite de inscripción', _limite, (f) => _limite = f),
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
                validator: (v) => v == null ? 'Elige el país' : null,
              ),
              espacio,
              DropdownButtonFormField<String>(
                key: ValueKey('ec-region-$_pais'),
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
                validator: (v) => v == null ? 'Obligatorio' : null,
              ),
              espacio,
              TextFormField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _direccion,
                decoration: const InputDecoration(
                    labelText: 'Dirección del recinto', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Modalidades', border: borde),
                child: Column(children: [
                  for (final m in modalidades)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(nombreModalidad(m)),
                      value: _modalidades.contains(m),
                      onChanged: (v) => setState(() =>
                          v == true ? _modalidades.add(m) : _modalidades.remove(m)),
                    ),
                ]),
              ),
              espacio,
              TextFormField(
                controller: _contacto,
                decoration: const InputDecoration(
                    labelText: 'Contacto del organizador',
                    hintText: 'Teléfono, WhatsApp o correo',
                    border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _descripcion,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descripción o bases del torneo', border: borde),
                validator: _obligatorio,
              ),
              const SizedBox(height: 12),
              Text('Datos opcionales', style: textos.titleMedium),
              espacio,
              TextFormField(
                controller: _costo,
                decoration: const InputDecoration(
                    labelText: 'Costo de inscripción',
                    hintText: 'Ej.: \$15.000 por categoría',
                    helperText: 'Solo informativo. El pago se hace fuera de la app.',
                    border: borde),
              ),
              espacio,
              TextFormField(
                controller: _reglamento,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Reglamento',
                    hintText: 'Texto o enlace',
                    border: borde),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar competencia'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
