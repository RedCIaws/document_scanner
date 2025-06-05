import 'dart:math';
import '../models/scan_document.dart';

class ScanSessionService {
  static ScanSession? _currentSession;

  /// Démarre une nouvelle session de scan
  static ScanSession startNewSession() {
    _currentSession = ScanSession(
      id: _generateId(),
      documents: [],
      createdAt: DateTime.now(),
    );
    return _currentSession!;
  }

  /// Obtient la session courante ou en crée une nouvelle
  static ScanSession getCurrentSession() {
    return _currentSession ?? startNewSession();
  }

  /// Ajoute un document à la session courante
  static ScanSession addDocumentToSession(String imagePath) {
    final currentSession = getCurrentSession();
    final document = ScanDocument(
      id: _generateId(),
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );

    _currentSession = currentSession.addDocument(document);
    return _currentSession!;
  }

  /// Met à jour un document dans la session
  static ScanSession updateDocumentInSession(
      String documentId, String newImagePath,
      {bool? isProcessed, String? processedImagePath}) {
    final currentSession = getCurrentSession();
    final existingDoc =
        currentSession.documents.firstWhere((doc) => doc.id == documentId);
    final updatedDoc = existingDoc.copyWith(
      imagePath: newImagePath,
      isProcessed: isProcessed,
      processedImagePath: processedImagePath,
    );

    _currentSession = currentSession.updateDocument(documentId, updatedDoc);
    return _currentSession!;
  }

  /// Supprime un document de la session
  static ScanSession removeDocumentFromSession(String documentId) {
    final currentSession = getCurrentSession();
    _currentSession = currentSession.removeDocument(documentId);
    return _currentSession!;
  }

  /// Obtient tous les chemins d'images de la session
  static List<String> getAllImagePaths() {
    return getCurrentSession()
        .documents
        .map((doc) => doc.processedImagePath ?? doc.imagePath)
        .toList();
  }

  /// Obtient le nombre de documents dans la session
  static int getDocumentCount() {
    return getCurrentSession().documents.length;
  }

  /// Réinitialise la session courante
  static void clearCurrentSession() {
    _currentSession = null;
  }

  /// Finalise la session (après génération PDF)
  static void finalizeSession() {
    clearCurrentSession();
  }

  /// Génère un ID unique
  static String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(9999);
    return '$timestamp$randomNum';
  }
}
