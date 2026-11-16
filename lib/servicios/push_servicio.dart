import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Avisos en el teléfono con la app cerrada (ver docs/decisiones.md).
///
/// Cada teléfono guarda su "dirección" en `usuarios/{uid}/tokens/{token}`.
/// El servidor (functions/index.js) la usa para hacer sonar el aviso.
class PushServicio {
  PushServicio._();

  static StreamSubscription<String>? _cambioToken;
  static StreamSubscription<RemoteMessage>? _toque;
  static String? _uid;
  static bool _inicialRevisado = false;

  static CollectionReference<Map<String, dynamic>> _tokens(String uid) =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid).collection('tokens');

  /// Pide permiso, guarda la dirección del teléfono y escucha los toques en
  /// la notificación. [alTocar] abre la campanita. Nunca lanza errores: sin
  /// permiso o sin Google Play, la app funciona igual (solo sin avisos).
  static Future<void> iniciar(String uid, {required void Function() alTocar}) async {
    if (_uid == uid && _toque != null) return;
    await _soltar();
    _uid = uid;
    try {
      final fcm = FirebaseMessaging.instance;
      // Android 13 o más: pide el permiso de notificaciones.
      final permiso = await fcm.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.authorized ||
          permiso.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await fcm.getToken();
        if (token != null) await _guardar(uid, token);
        _cambioToken = fcm.onTokenRefresh.listen((t) => _guardar(uid, t), onError: (_) {});
      }
      _toque = FirebaseMessaging.onMessageOpenedApp.listen((_) => alTocar());
      // La app estaba cerrada y se abrió tocando la notificación.
      if (!_inicialRevisado) {
        _inicialRevisado = true;
        final inicial = await fcm.getInitialMessage();
        if (inicial != null) alTocar();
      }
    } catch (_) {}
  }

  static Future<void> _guardar(String uid, String token) async {
    try {
      await _tokens(uid).doc(token).set({'creado': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  static Future<void> _soltar() async {
    await _cambioToken?.cancel();
    await _toque?.cancel();
    _cambioToken = null;
    _toque = null;
    _uid = null;
  }

  /// Quita este teléfono de la cuenta (no le llegan más avisos de ella).
  static Future<void> olvidarTelefono(String uid) async {
    await _soltar();
    try {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken().timeout(const Duration(seconds: 5));
      if (token != null) await _tokens(uid).doc(token).delete();
      await fcm.deleteToken();
    } catch (_) {}
  }

  /// Cerrar sesión: primero se quita el teléfono (hace falta la sesión).
  static Future<void> salir() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await olvidarTelefono(uid);
    await FirebaseAuth.instance.signOut();
  }
}
