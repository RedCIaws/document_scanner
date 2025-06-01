class ScanDocument {
  final String id;
  final String imagePath;
  final String? processedImagePath;
  final DateTime createdAt;
  final bool isProcessed;

  ScanDocument({
    required this.id,
    required this.imagePath,
    this.processedImagePath,
    required this.createdAt,
    this.isProcessed = false,
  });

  ScanDocument copyWith({
    String? id,
    String? imagePath,
    String? processedImagePath,
    DateTime? createdAt,
    bool? isProcessed,
  }) {
    return ScanDocument(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      createdAt: createdAt ?? this.createdAt,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }
}

class ScanSession {
  final String id;
  final List<ScanDocument> documents;
  final DateTime createdAt;

  ScanSession({
    required this.id,
    required this.documents,
    required this.createdAt,
  });

  ScanSession copyWith({
    String? id,
    List<ScanDocument>? documents,
    DateTime? createdAt,
  }) {
    return ScanSession(
      id: id ?? this.id,
      documents: documents ?? this.documents,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ScanSession addDocument(ScanDocument document) {
    return copyWith(
      documents: [...documents, document],
    );
  }

  ScanSession removeDocument(String documentId) {
    return copyWith(
      documents: documents.where((doc) => doc.id != documentId).toList(),
    );
  }

  ScanSession updateDocument(String documentId, ScanDocument updatedDocument) {
    return copyWith(
      documents: documents
          .map((doc) => doc.id == documentId ? updatedDocument : doc)
          .toList(),
    );
  }
}
