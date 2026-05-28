import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Servizio per gestire il caricamento di file su Firebase Storage
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Carica un documento del driver su Firebase Storage
  ///
  /// [file] - File da caricare
  /// [driverId] - ID del driver (opzionale, se non disponibile usa timestamp)
  ///
  /// Returns: URL pubblico del file caricato
  Future<String> uploadDriverDocument(File file, {int? driverId}) async {
    try {
      // Genera nome file univoco
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final fileName = driverId != null
          ? 'driver_${driverId}_doc_$timestamp.$extension'
          : 'driver_doc_$timestamp.$extension';

      // Path su Firebase Storage: driver_documents/{fileName}
      final storageRef = _storage.ref().child('driver_documents/$fileName');

      print('📤 [FIREBASE] Caricamento documento: $fileName');

      // Upload del file
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'driverId': driverId?.toString() ?? 'pending',
          },
        ),
      );

      // Attendi completamento upload
      final snapshot = await uploadTask;

      print('✅ [FIREBASE] Upload completato: ${snapshot.state}');

      // Ottieni URL pubblico
      final downloadUrl = await storageRef.getDownloadURL();

      print('🔗 [FIREBASE] URL documento: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ [FIREBASE] Errore upload: $e');
      throw Exception('Errore durante il caricamento del documento: $e');
    }
  }

  /// Determina il content type in base all'estensione
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Elimina un documento da Firebase Storage (opzionale, per gestione admin)
  Future<void> deleteDriverDocument(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('🗑️ [FIREBASE] Documento eliminato: ${ref.fullPath}');
    } catch (e) {
      print('⚠️ [FIREBASE] Errore eliminazione: $e');
      // Non bloccare in caso di errore
    }
  }
}
