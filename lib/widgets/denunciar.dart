import 'package:flutter/material.dart';

import '../servicios/errores.dart';
import '../servicios/sesion.dart';
import '../servicios/social_servicio.dart';

/// Pide el motivo y envía la denuncia a los administradores.
Future<void> denunciar(
  BuildContext context, {
  required String tipo,
  required String ruta,
  required String autorUid,
  required String vistaPrevia,
}) async {
  final mensajes = ScaffoldMessenger.of(context);
  final texto = TextEditingController();
  final motivo = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Denunciar'),
        content: TextField(
          controller: texto,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '¿Qué pasa con este contenido?',
            helperText: 'Lo revisará un administrador.',
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
            child: const Text('Enviar denuncia'),
          ),
        ],
      ),
    ),
  );
  if (motivo == null) return;
  try {
    await SocialServicio().denunciar(
      tipo: tipo,
      ruta: ruta,
      autorUid: autorUid,
      vistaPrevia: vistaPrevia,
      motivo: motivo,
      denuncianteUid: Sesion.uid ?? '',
    );
    mensajes.showSnackBar(const SnackBar(
        content: Text('Denuncia enviada. Gracias por avisar.')));
  } catch (e) {
    mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
  }
}

/// Confirmación simple de sí o no.
Future<bool> confirmar(BuildContext context, String pregunta, {String si = 'Sí'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(pregunta),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true), child: Text(si)),
      ],
    ),
  );
  return r ?? false;
}
