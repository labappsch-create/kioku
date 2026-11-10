import 'package:flutter/material.dart';

import '../servicios/social_servicio.dart';
import '../tema.dart';
import 'avatar.dart';

/// Alto de la portada.
const double altoPortada = 170;

/// Franja de color cuando no hay portada (o no se puede ver).
const Widget franjaPortada = DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [negroKioku, rojoKioku],
    ),
  ),
);

/// Portada ancha con una foto redonda encima (perfil de persona o de dojo).
class CabeceraPortada extends StatelessWidget {
  const CabeceraPortada({
    super.key,
    required this.portadaUrl,
    required this.circulo,
  });

  /// Futuro con el enlace de la portada, o null si no hay.
  final Future<String?> portadaUrl;

  /// La foto redonda (avatar o logo).
  final Widget circulo;

  @override
  Widget build(BuildContext context) {
    const radio = 48.0;
    return SizedBox(
      // Portada + medio círculo + el borde blanco.
      height: altoPortada + radio + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: altoPortada,
            width: double.infinity,
            child: FutureBuilder<String?>(
              future: portadaUrl,
              builder: (context, snap) {
                final url = snap.data;
                if (url == null) return franjaPortada;
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => franjaPortada,
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: altoPortada - radio,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: circulo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del perfil de una persona.
class CabeceraPerfil extends StatelessWidget {
  const CabeceraPerfil({
    super.key,
    required this.uid,
    required this.nombre,
    this.version = 0,
  });

  final String uid;
  final String nombre;

  /// Cambiar este número fuerza a volver a cargar la portada y la foto.
  final int version;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: fotosCambiadas,
      builder: (context, n, _) => CabeceraPortada(
        key: ValueKey('cab-$uid-$version-$n'),
        portadaUrl: SocialServicio().portada(uid),
        circulo: Avatar(key: ValueKey('av-$uid-$n'), uid: uid, nombre: nombre, radio: 48),
      ),
    );
  }
}
