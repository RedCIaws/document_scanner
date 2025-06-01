import 'package:flutter/material.dart';
import 'dart:io';
import '../services/image_processing_service.dart';
import '../services/pdf_service.dart';
import '../services/scan_session.dart';
import '../models/scan_document.dart';
import 'camera_screen.dart';
import '../main.dart'; // Pour accéder à la liste cameras

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isFirstDocument; // Nouveau paramètre

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
  String? colorImagePath; // Garde une référence à la version couleur
  String? currentDocumentId; // ID du document courant
  bool isProcessing = false;
  bool isConverting = false;
  bool isBlackAndWhite = false; // Track du mode N&B
  String processingStatus = '';
  int totalDocuments = 0; // Nombre total de documents dans la session

  @override
  void initState() {
    super.initState();
    currentImagePath = widget.imagePath;
    colorImagePath =
        widget.imagePath; // Sauvegarder la version couleur originale

    // Ajouter le document à la session
    if (widget.isFirstDocument) {
      ScanSessionService.startNewSession();
    }
    final session = ScanSessionService.addDocumentToSession(widget.imagePath);
    currentDocumentId = session.documents.last.id;
    totalDocuments = session.documents.length;
  }

  /// Affiche un message en remplaçant le précédent
  void _showMessage(String message, {Color? backgroundColor, IconData? icon}) {
    // Supprimer le SnackBar précédent immédiatement
    ScaffoldMessenger.of(context).clearSnackBars();

    // Afficher le nouveau en haut de l'écran
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
        margin: const EdgeInsets.fromLTRB(
            16, 16, 16, 0), // En haut : top=16, bottom=0
      ),
    );
  }

  Future<void> _processImage() async {
    setState(() {
      isProcessing = true;
      processingStatus = 'Traitement en cours...';
    });

    try {
      // Traiter l'image avec OpenCV
      final processedPath =
          await ImageProcessingService.processDocument(currentImagePath);

      // Mettre à jour le chemin de l'image courante
      setState(() {
        currentImagePath = processedPath;
      });

      // Mettre à jour le document dans la session avec le chemin traité
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
    setState(() {
      isProcessing = true;
      processingStatus = 'Retournement de l\'image...';
    });

    try {
      final flippedPath =
          await ImageProcessingService.flipImageHorizontally(currentImagePath);

      setState(() {
        currentImagePath = flippedPath;
        colorImagePath = flippedPath; // Mettre à jour la version couleur
        isBlackAndWhite = false; // Reset du mode N&B
        processingStatus = 'Image retournée !';
      });

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
    setState(() {
      isProcessing = true;
      processingStatus = isBlackAndWhite
          ? 'Retour en couleur...'
          : 'Conversion noir et blanc...';
    });

    try {
      if (isBlackAndWhite) {
        // Revenir à la version couleur
        setState(() {
          currentImagePath = colorImagePath!;
          isBlackAndWhite = false;
          processingStatus = 'Version couleur restaurée !';
        });

        // Mettre à jour le document dans la session avec la version couleur
        if (currentDocumentId != null) {
          ScanSessionService.updateDocumentInSession(
            currentDocumentId!,
            colorImagePath!,
            processedImagePath: null, // Réinitialiser le chemin traité
          );
        }

        _showMessage(
          'Retour en couleur !',
          backgroundColor: Colors.green,
          icon: Icons.color_lens,
        );
      } else {
        // Convertir en noir et blanc
        final bwPath = await ImageProcessingService.convertToBlackAndWhite(
            currentImagePath);

        setState(() {
          currentImagePath = bwPath;
          isBlackAndWhite = true;
          processingStatus = 'Conversion terminée !';
        });

        // Mettre à jour le document dans la session avec la version N&B
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
      }
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

  Future<void> _addAnotherPage() async {
    // Naviguer vers CameraScreen pour ajouter une nouvelle page
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(cameras: cameras),
      ),
    );

    // Mettre à jour le compteur de documents après le retour
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
    // Retourner à l'écran principal
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

      // Afficher le dialogue de succès
      _showPdfSuccessDialog(pdfPath, documentCount);

      // Réinitialiser la session après la sauvegarde réussie
      ScanSessionService.finalizeSession();

      // Retourner à l'écran principal après un court délai
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
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
    // Extraire le nom du fichier et déterminer l'emplacement
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await PdfService.sharePdf(pdfPath);
                } catch (e) {
                  _showMessage(
                    'Erreur partage: $e',
                    backgroundColor: Colors.red,
                    icon: Icons.error,
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
      appBar: AppBar(
        title: Text(
            'Aperçu (${ScanSessionService.getDocumentCount()} page${ScanSessionService.getDocumentCount() > 1 ? 's' : ''})'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: isProcessing ? null : _processImage,
            tooltip: 'Optimiser l\'image',
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
      body: Column(
        children: [
          // Indicateur de traitement
          if (isProcessing || isConverting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    isConverting ? 'Génération du PDF...' : processingStatus,
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: Card(
                elevation: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(currentImagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Boutons d'action
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Première ligne de boutons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : _toggleBlackAndWhite,
                        icon: Icon(isBlackAndWhite
                            ? Icons.color_lens
                            : Icons.contrast),
                        label: Text(isBlackAndWhite ? 'Couleur' : 'N&B'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBlackAndWhite
                              ? Colors.blue
                              : Colors.grey.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : _flipImage,
                        icon: const Icon(Icons.flip),
                        label: const Text('Retourner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Reprendre'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bouton ajouter une page
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : _addAnotherPage,
                    icon: const Icon(Icons.add_photo_alternate, size: 24),
                    label: const Text(
                      'Ajouter une page',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bouton principal PDF
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
                        : const Icon(Icons.picture_as_pdf, size: 24),
                    label: Text(
                      isConverting
                          ? 'Conversion...'
                          : 'Générer PDF (${ScanSessionService.getDocumentCount()} page${ScanSessionService.getDocumentCount() > 1 ? 's' : ''})',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
