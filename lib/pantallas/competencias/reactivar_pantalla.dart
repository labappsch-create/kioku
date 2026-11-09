import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';

/// Reactivar un torneo suspendido con fechas nuevas.
class ReactivarPantalla extends StatefulWidget {
  const ReactivarPantalla({super.key, required this.competencia});

  final Competencia competencia;

  @override
  State<ReactivarPantalla> createState() => _ReactivarPantallaState();
}

class _ReactivarPantallaState extends State<ReactivarPantalla> {
  DateTime? _inicio;
  DateTime? _fin;
  DateTime? _limite;
  bool _guardando = false;
  String? _error;

  Future<void> _elegir(DateTime? actual, String ayuda, ValueChanged<DateTime> alElegir) async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: actual ?? hoy,
      firstDate: soloDia(hoy),
      lastDate: DateTime(hoy.year + 3),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: ayuda,
    );
    if (f != null) setState(() => alElegir(soloDia(f)));
  }

  Widget _campo(String titulo, DateTime? valor, ValueChanged<DateTime> alElegir) {
    return InkWell(
      onTap: () => _elegir(valor, titulo, alElegir),
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

  Future<void> _reactivar() async {
    String? problema;
    final hoy = soloDia(DateTime.now());
    if (_inicio == null || _fin == null || _limite == null) {
      problema = 'Elige las tres fechas.';
    } else if (_fin!.isBefore(_inicio!)) {
      problema = 'El último día no puede ser antes del primero.';
    } else if (_limite!.isAfter(_fin!)) {
      problema = 'La fecha límite de inscripción no puede ser después del último día.';
    } else if (_limite!.isBefore(hoy)) {
      problema = 'La fecha límite de inscripción no puede ser en el pasado.';
    }
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final navegador = Navigator.of(context);
      final mensajes = ScaffoldMessenger.of(context);
      await CompetenciasServicio().reactivar(
        widget.competencia,
        inicio: _inicio!,
        fin: _fin!,
        limite: _limite!,
      );
      mensajes.showSnackBar(const SnackBar(content: Text('Torneo reactivado')));
      navegador.pop();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const espacio = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Reactivar torneo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.competencia.nombre,
              style: Theme.of(context).textTheme.titleMedium),
          espacio,
          const Text(
            'Elige las nuevas fechas. Las inscripciones se mantienen. Hasta la '
            'nueva fecha límite, cada atleta (o su sensei) podrá anular su '
            'inscripción aunque esté confirmada, por si la nueva fecha no le sirve.',
          ),
          espacio,
          _campo('Primer día del evento', _inicio, (f) => _inicio = f),
          espacio,
          _campo('Último día del evento', _fin, (f) => _fin = f),
          espacio,
          _campo('Fecha límite de inscripción', _limite, (f) => _limite = f),
          if (_error != null) ...[
            espacio,
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _reactivar,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Reactivar'),
          ),
        ],
      ),
    );
  }
}
