import 'package:flutter/material.dart';
import 'dart:io';
import '../services/image_processing_service.dart';
import '../services/pdf_service.dart';
import '../services/scan_session.dart';
import '../models/scan_document.dart';
import '../theme/app_theme.dart';
import 'camera_screen.dart';
import '../main.dart'; // Pour accéder à la liste cameras

// Classe pour gérer l'historique des actions
class ImageAction {
  final String imagePath;
  final String actionName;
  final DateTime timestamp;

  ImageAction({
    required this.imagePath,
    required this.actionName,
    required this.timestamp,
  });
}

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isFirstDocument;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    this.isFirstDocument = true,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String currentImagePath = '';
  String originalImagePath = ''; // Chemin de l'image originale
  String? currentDocumentId;
  bool isProcessing = false;
  bool isConverting = false;
  String processingStatus = '';
  int totalDocuments = 0;

  // Historique des actions pour le système d'undo
  List<ImageAction> actionHistory = [];
  
  // Suivi des opérations appliquées pour éviter les doublons
  Set<String> appliedOperations = {};

  @override
  void initState() {
    super.initState();
    currentImagePath = widget.imagePath;
    originalImagePath = widget.imagePath; // Sauvegarder l'original

    // Ajouter le document à la session
    if (widget.isFirstDocument) {
      ScanSessionService.startNewSession();
    }
    final session = ScanSessionService.addDocumentToSession(widget.imagePath);
    currentDocumentId = session.documents.last.id;
    totalDocuments = session.documents.length;

    // Initialiser l'historique avec l'image originale
    actionHistory.add(ImageAction(
      imagePath: originalImagePath,
      actionName: 'Original',
      timestamp: DateTime.now(),
    ));
  }

  /// Affiche un message en remplaçant le précédent
  void _showMessage(String message, {Color? backgroundColor, IconData? icon}) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      ),
    );
  }

  /// Ajoute une action à l'historique
  void _addToHistory(String imagePath, String actionName) {
    actionHistory.add(ImageAction(
      imagePath: imagePath,
      actionName: actionName,
      timestamp: DateTime.now(),
    ));

    // Ajouter l'opération aux opérations appliquées
    appliedOperations.add(actionName);

    // Limiter l'historique à 10 actions pour éviter une consommation excessive de mémoire
    if (actionHistory.length > 10) {
      actionHistory.removeAt(0);
    }
  }

  /// Annule la dernière action (Undo)
  Future<void> _undoLastAction() async {
    if (actionHistory.length <= 1) {
      _showMessage(
        'Aucune action à annuler',
        backgroundColor: Colors.orange,
        icon: Icons.info,
      );
      return;
    }

    // Supprimer l'action courante et la retirer des opérations appliquées
    final removedAction = actionHistory.removeLast();
    appliedOperations.remove(removedAction.actionName);

    // Revenir à l'action précédente
    final previousAction = actionHistory.last;

    setState(() {
      currentImagePath = previousAction.imagePath;
      isProcessing = false;
    });

    // Mettre à jour le document dans la session
    if (currentDocumentId != null) {
      ScanSessionService.updateDocumentInSession(
        currentDocumentId!,
        currentImagePath,
        processedImagePath: previousAction.imagePath != originalImagePath
            ? previousAction.imagePath
            : null,
        isProcessed: previousAction.imagePath != originalImagePath,
      );
    }

    _showMessage(
      'Action annulée - Retour à: ${previousAction.actionName}',
      backgroundColor: Colors.blue,
      icon: Icons.undo,
    );
  }

  Future<void> _processImage() async {
    // Vérifier si l'opération a déjà été appliquée
    if (appliedOperations.contains('Optimisé')) {
      _showMessage(
        'Image déjà optimisée. Annulez d\'abord l\'opération précédente.',
        backgroundColor: Colors.orange,
        icon: Icons.info,
      );
      return;
    }

    setState(() {
      isProcessing = true;
      processingStatus = 'Traitement en cours...';
    });

    try {
      final processedPath =
          await ImageProcessingService.processDocument(currentImagePath);

      setState(() {
        currentImagePath = processedPath;
      });

      // Ajouter à l'historique
      _addToHistory(processedPath, 'Optimisé');

      // Mettre à jour le document dans la session
      if (currentDocumentId != null) {
        ScanSessionService.updateDocumentInSession(
          currentDocumentId!,
          currentImagePath,
          isProcessed: true,
          processedImagePath: processedPath,
        );
      }

      _showMessage(
        'Image optimisée !',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      _showMessage(
        'Erreur: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _flipImage() async {
    // Vérifier si l'opération a déjà été appliquée
    if (appliedOperations.contains('Retourné')) {
      _showMessage(
        'Image déjà retournée. Annulez d\'abord l\'opération précédente.',
        backgroundColor: Colors.orange,
        icon: Icons.info,
      );
      return;
    }

    setState(() {
      isProcessing = true;
      processingStatus = 'Retournement de l\'image...';
    });

    try {
      final flippedPath =
          await ImageProcessingService.flipImageHorizontally(currentImagePath);

      setState(() {
        currentImagePath = flippedPath;
      });

      // Ajouter à l'historique
      _addToHistory(flippedPath, 'Retourné');

      _showMessage(
        'Image retournée !',
        backgroundColor: Colors.blue,
        icon: Icons.flip,
      );
    } catch (e) {
      _showMessage(
        'Erreur retournement: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _toggleBlackAndWhite() async {
    // Vérifier si l'opération a déjà été appliquée
    if (appliedOperations.contains('Noir & Blanc')) {
      _showMessage(
        'Image déjà en noir et blanc. Annulez d\'abord l\'opération précédente.',
        backgroundColor: Colors.orange,
        icon: Icons.info,
      );
      return;
    }

    setState(() {
      isProcessing = true;
      processingStatus = 'Conversion noir et blanc...';
    });

    try {
      final bwPath =
          await ImageProcessingService.convertToBlackAndWhite(currentImagePath);

      setState(() {
        currentImagePath = bwPath;
      });

      // Ajouter à l'historique
      _addToHistory(bwPath, 'Noir & Blanc');

      // Mettre à jour le document dans la session
      if (currentDocumentId != null) {
        ScanSessionService.updateDocumentInSession(
          currentDocumentId!,
          currentImagePath,
          processedImagePath: bwPath,
        );
      }

      _showMessage(
        'Converti en noir et blanc !',
        backgroundColor: Colors.grey.shade700,
        icon: Icons.contrast,
      );
    } catch (e) {
      _showMessage(
        'Erreur: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  /// Reprendre la photo (supprimer le document courant et retourner à la caméra)
  Future<void> _retakePhoto() async {
    // Supprimer le document courant de la session
    if (currentDocumentId != null) {
      ScanSessionService.removeDocumentFromSession(currentDocumentId!);
    }

    // Retourner à la caméra
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: cameras),
      ),
    );
  }

  Future<void> _addAnotherPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: cameras),
      ),
    );

    setState(() {
      totalDocuments = ScanSessionService.getDocumentCount();
    });
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Wrap(
            children: const [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Effacer tous les documents ?'),
            ],
          ),
          content: Text(
              'Voulez-vous vraiment effacer les ${ScanSessionService.getDocumentCount()} document${ScanSessionService.getDocumentCount() > 1 ? 's' : ''} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearDocuments();
              },
              child: const Text('Effacer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _clearDocuments() {
    ScanSessionService.clearCurrentSession();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _generateMultiPagePdf() async {
    setState(() {
      isConverting = true;
    });

    try {
      final imagePaths = ScanSessionService.getAllImagePaths();
      final documentCount = ScanSessionService.getDocumentCount();

      final pdfPath = await PdfService.createPdf(
        imagePaths,
        fileName:
            'scan_${documentCount}pages_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      _showPdfSuccessDialog(pdfPath, documentCount);

      ScanSessionService.finalizeSession();
    } catch (e) {
      _showMessage(
        'Erreur PDF: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        isConverting = false;
      });
    }
  }

  void _showPdfSuccessDialog(String pdfPath, int pageCount) {
    final fileName = pdfPath.split('/').last;
    final isInDownloads = pdfPath.contains('/Download/');
    final isInPublicDocs = pdfPath.contains('/storage/emulated/0/Documents');

    String locationText;
    if (isInDownloads) {
      locationText = 'Téléchargements > $fileName';
    } else if (isInPublicDocs) {
      locationText = 'Documents > $fileName';
    } else {
      locationText = 'Dossier app (partage uniquement)';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Wrap(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('PDF Sauvegardé !'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '✅ PDF créé avec $pageCount page${pageCount > 1 ? 's' : ''} :'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.folder,
                              color: Colors.green.shade700, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Emplacement:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(locationText, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf,
                              color: Colors.red.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Fichier:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(fileName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        locationText.contains('app')
                            ? 'Utilisez "Partager" pour envoyer le PDF'
                            : 'Accessible via l\'app "Fichiers"',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst); // Go back to main screen
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await PdfService.openPdf(pdfPath);
                  Navigator.of(context).pop(); // Close dialog after successful open
                  Navigator.of(context).popUntil((route) => route.isFirst); // Go back to main screen
                } catch (e) {
                  // Don't close dialog on error, just show message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Utilisez "Partager" pour ouvrir le PDF'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Ouvrir'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await PdfService.sharePdf(pdfPath);
                  Navigator.of(context).pop(); // Close dialog after successful share
                  Navigator.of(context).popUntil((route) => route.isFirst); // Go back to main screen
                } catch (e) {
                  // Don't close dialog on error, just show message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur partage: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Partager'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          // Bouton Undo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed:
                (isProcessing || isConverting || actionHistory.length <= 1)
                    ? null
                    : _undoLastAction,
            tooltip: 'Annuler la dernière action',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: isProcessing || isConverting
                ? null
                : _showClearConfirmationDialog,
            tooltip: 'Effacer tous les documents',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.appGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
          // Indicateur de traitement
          if (isProcessing || isConverting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.lightCard,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.darkTeal),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    isConverting ? 'Génération du PDF...' : processingStatus,
                    style: TextStyle(color: AppTheme.darkTeal, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Affichage de l'action courante
          if (actionHistory.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withOpacity(0.15),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: AppTheme.darkTeal),
                  const SizedBox(width: 8),
                  Text(
                    'État actuel: ${actionHistory.last.actionName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (actionHistory.length > 1)
                    Text(
                      '${actionHistory.length - 1} action${actionHistory.length > 2 ? 's' : ''} à annuler',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Image.file(
                File(currentImagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Boutons d'action
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                // Première ligne de boutons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isProcessing || appliedOperations.contains('Optimisé')) ? null : _processImage,
                        child: const Icon(Icons.auto_fix_high),
                        style: appliedOperations.contains('Optimisé')
                            ? AppTheme.processingButtonAppliedStyle
                            : AppTheme.processingButtonStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isProcessing || appliedOperations.contains('Noir & Blanc')) ? null : _toggleBlackAndWhite,
                        child: const Icon(Icons.contrast),
                        style: appliedOperations.contains('Noir & Blanc')
                            ? AppTheme.processingButtonAppliedStyle
                            : AppTheme.processingButtonStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isProcessing || appliedOperations.contains('Retourné')) ? null : _flipImage,
                        child: const Icon(Icons.flip),
                        style: appliedOperations.contains('Retourné')
                            ? AppTheme.processingButtonAppliedStyle
                            : AppTheme.processingButtonStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : _retakePhoto,
                        child: const Icon(Icons.refresh),
                        style: AppTheme.processingButtonStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Add Page Button (Pastel Green)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : _addAnotherPage,
                    icon: const Icon(Icons.add, size: 24),
                    label: const Text('Ajouter Page'),
                    style: AppTheme.addPageButtonStyle,
                  ),
                ),
                const SizedBox(height: 12),

                // Generate PDF Button (Pastel Red)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (isProcessing || isConverting)
                        ? null
                        : _generateMultiPagePdf,
                    icon: isConverting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.description, size: 24),
                    label: Text(
                      isConverting
                          ? 'Conversion...'
                          : 'Générer PDF (${ScanSessionService.getDocumentCount()} page${ScanSessionService.getDocumentCount() > 1 ? 's' : ''})',
                    ),
                    style: AppTheme.generatePdfButtonStyle,
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
