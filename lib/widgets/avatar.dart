import 'package:flutter/material.dart';

import '../servicios/social_servicio.dart';

/// Foto de perfil redonda. Si no hay foto (o no se puede ver, como la de un
/// menor que no es tu amigo), muestra la inicial del nombre.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.uid,
    required this.nombre,
    this.radio = 20,
    this.urlFija,
  });

  final String uid;
  final String nombre;
  final double radio;

  /// Para logos de dojos: se usa este enlace en vez de buscar la foto.
  final String? urlFija;

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase();
    Widget conUrl(String? url) => CircleAvatar(
          radius: radio,
          foregroundImage: url == null ? null : NetworkImage(url),
          child: Text(inicial, style: TextStyle(fontSize: radio * 0.8)),
        );
    if (urlFija != null || uid.isEmpty) return conUrl(urlFija);
    return FutureBuilder<String?>(
      future: SocialServicio().fotoPerfil(uid),
      builder: (context, snap) => conUrl(snap.data),
    );
  }
}
