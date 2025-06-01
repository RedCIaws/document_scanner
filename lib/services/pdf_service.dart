import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfService {
  /// Crée un PDF à partir d'une liste d'images
  static Future<String> createPdf(List<String> imagePaths,
      {String? fileName}) async {
    try {
      // Demander les permissions de stockage
      await _requestStoragePermission();

      final pdf = pw.Document();

      // Ajouter chaque image comme une page
      for (String imagePath in imagePaths) {
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final image = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.all(20),
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                    width: PdfPageFormat.a4.width - 40,
                    height: PdfPageFormat.a4.height - 40,
                  ),
                );
              },
            ),
          );
        }
      }

      // Sauvegarder directement dans le dossier Downloads accessible
      final String pdfFileName =
          fileName ?? 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String pdfPath = await _getSavePath(pdfFileName);

      final File pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      print('✅ PDF sauvegardé dans: $pdfPath');
      return pdfPath;
    } catch (e) {
      print('❌ Erreur création PDF: $e');
      throw Exception('Impossible de créer le PDF: $e');
    }
  }

  /// Demande les permissions de stockage nécessaires
  static Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Demander la permission de base
      final status = await Permission.storage.request();

      if (status.isPermanentlyDenied) {
        // Guider l'utilisateur vers les paramètres
        print('⚠️ Permission refusée de façon permanente');
        await openAppSettings();
      } else if (status.isDenied) {
        print('⚠️ Permission refusée, utilisation du dossier app');
      }
    }
  }

  /// Obtient le chemin de sauvegarde accessible à l'utilisateur
  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      // Essayer d'abord le dossier public Documents
      try {
        final Directory publicDocsDir =
            Directory('/storage/emulated/0/Documents');
        if (await publicDocsDir.exists() ||
            await _createDirectoryIfNeeded(publicDocsDir)) {
          return '${publicDocsDir.path}/$fileName';
        }
      } catch (e) {
        print('Impossible d\'accéder au dossier Documents public: $e');
      }

      // Fallback: dossier Downloads
      try {
        final Directory downloadsDir =
            Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          return '${downloadsDir.path}/$fileName';
        }
      } catch (e) {
        print('Impossible d\'accéder au dossier Downloads: $e');
      }

      // Fallback: dossier Documents externe (accessible via partage)
      try {
        final Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final Directory documentsDir =
              Directory('${externalDir.path}/Documents');
          if (!await documentsDir.exists()) {
            await documentsDir.create(recursive: true);
          }
          return '${documentsDir.path}/$fileName';
        }
      } catch (e) {
        print('Impossible d\'accéder au stockage externe: $e');
      }
    }

    // Fallback final: dossier app (toujours accessible)
    final Directory appDir = await getApplicationDocumentsDirectory();
    print('📁 Utilisation du dossier app: ${appDir.path}');
    return '${appDir.path}/$fileName';
  }

  /// Crée un dossier si nécessaire et possible
  static Future<bool> _createDirectoryIfNeeded(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      print('Impossible de créer le dossier: $e');
      return false;
    }
  }

  /// Crée un PDF à partir d'une seule image
  static Future<String> createSinglePagePdf(String imagePath,
      {String? fileName}) async {
    return await createPdf([imagePath], fileName: fileName);
  }

  /// Partage le PDF
  static Future<void> sharePdf(String pdfPath) async {
    try {
      final File pdfFile = File(pdfPath);
      if (await pdfFile.exists()) {
        await Printing.sharePdf(
          bytes: await pdfFile.readAsBytes(),
          filename: pdfFile.path.split('/').last,
        );
      }
    } catch (e) {
      print('Erreur partage PDF: $e');
      throw Exception('Impossible de partager le PDF: $e');
    }
  }

  /// Ouvre le PDF dans un viewer
  static Future<void> openPdf(String pdfPath) async {
    try {
      final File pdfFile = File(pdfPath);
      if (await pdfFile.exists()) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => await pdfFile.readAsBytes(),
        );
      }
    } catch (e) {
      print('Erreur ouverture PDF: $e');
      throw Exception('Impossible d\'ouvrir le PDF: $e');
    }
  }

  /// Obtient la liste des PDFs sauvegardés
  static Future<List<File>> getSavedPdfs() async {
    try {
      final String downloadsPath = await _getSavePath('');
      final Directory dir =
          Directory(downloadsPath.substring(0, downloadsPath.lastIndexOf('/')));

      if (await dir.exists()) {
        final List<FileSystemEntity> files = dir.listSync();
        return files
            .where((file) => file is File && file.path.endsWith('.pdf'))
            .cast<File>()
            .toList();
      }

      return [];
    } catch (e) {
      print('Erreur récupération PDFs: $e');
      return [];
    }
  }

  /// Supprime un PDF
  static Future<bool> deletePdf(String pdfPath) async {
    try {
      final File pdfFile = File(pdfPath);
      if (await pdfFile.exists()) {
        await pdfFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur suppression PDF: $e');
      return false;
    }
  }
}
