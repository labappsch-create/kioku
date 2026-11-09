import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Una foto elegida en el teléfono, ya achicada, lista para subir.
class FotoElegida {
  const FotoElegida(this.bytes, this.tipo);

  final Uint8List bytes;
  final String tipo;

  String get extension => tipo == 'image/png' ? 'png' : 'jpg';
}

/// Elige, achica y sube fotos.
class FotosServicio {
  FotosServicio({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _picker = ImagePicker();

  static String _tipo(XFile f) {
    final m = f.mimeType;
    if (m != null && m.startsWith('image/')) return m;
    return f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }

  static Future<FotoElegida> _leer(XFile f) async =>
      FotoElegida(await f.readAsBytes(), _tipo(f));

  /// Elige hasta [maximo] fotos de la galería, achicadas para publicar.
  Future<List<FotoElegida>> elegirVarias(int maximo) async {
    if (maximo <= 0) return const [];
    final List<XFile> archivos;
    if (maximo == 1) {
      final f = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 75);
      archivos = f == null ? [] : [f];
    } else {
      archivos = await _picker.pickMultiImage(
          maxWidth: 1600, maxHeight: 1600, imageQuality: 75, limit: maximo);
    }
    final elegidas = <FotoElegida>[];
    for (final f in archivos.take(maximo)) {
      elegidas.add(await _leer(f));
    }
    return elegidas;
  }

  /// Elige una sola foto, achicada (foto de perfil, logo o afiche).
  Future<FotoElegida?> elegirUna({double lado = 800}) async {
    final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: lado,
        maxHeight: lado,
        imageQuality: 80);
    return f == null ? null : _leer(f);
  }

  /// Sube la foto y devuelve su enlace.
  Future<String> subir(String ruta, FotoElegida foto) async {
    final ref = _storage.ref(ruta);
    await ref.putData(foto.bytes, SettableMetadata(contentType: foto.tipo));
    return ref.getDownloadURL();
  }

  /// Borra una foto. Si ya no existe o falla, no pasa nada.
  Future<void> borrar(String ruta) async {
    if (ruta.isEmpty) return;
    try {
      await _storage.ref(ruta).delete();
    } catch (_) {}
  }
}
