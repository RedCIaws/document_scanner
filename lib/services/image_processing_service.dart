import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'dart:math' as math;

class ImageProcessingService {
  /// Détecte automatiquement les contours du document et applique la correction de perspective
  static Future<String> processDocument(String imagePath) async {
    try {
      print('🔍 Début du traitement avec OpenCV...');

      // 1. Charger l'image avec OpenCV
      final cv.Mat originalImage = cv.imread(imagePath);
      if (originalImage.isEmpty) {
        throw Exception('Impossible de charger l\'image');
      }

      print('📐 Image chargée: ${originalImage.cols}x${originalImage.rows}');

      // 2. Redimensionner pour le traitement (améliore les performances)
      final cv.Mat resized = _resizeImage(originalImage, 800);
      final double scale = originalImage.cols / resized.cols;

      // 3. Préparation de l'image pour la détection des contours
      final cv.Mat gray = cv.cvtColor(resized, cv.COLOR_BGR2GRAY);
      final cv.Mat blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final cv.Mat edges = cv.canny(blurred, 75, 200);

      print('🔍 Détection des contours...');

      // 4. Détecter les contours du document
      final corners = _findDocumentCorners(edges);

      if (corners.isNotEmpty) {
        print('📍 Coins détectés: ${corners.length}');

        // 5. Ajuster les coordonnées à l'image originale
        final adjustedCorners = corners
            .map((corner) => cv.Point2f(
                  corner.x * scale,
                  corner.y * scale,
                ))
            .toList();

        // 6. Appliquer la correction de perspective
        final cv.Mat corrected =
            _perspectiveCorrection(originalImage, adjustedCorners);

        // 7. Améliorer la qualité de l'image corrigée
        final cv.Mat enhanced = _enhanceDocument(corrected);

        // 8. Sauvegarder l'image traitée
        final String processedPath =
            imagePath.replaceAll('.jpg', '_processed.jpg');
        cv.imwrite(processedPath, enhanced);

        print('✅ Traitement terminé: $processedPath');
        return processedPath;
      } else {
        print('⚠️ Aucun document détecté, amélioration simple...');

        // Si pas de document détecté, améliorer l'image originale
        final cv.Mat enhanced = _enhanceDocument(originalImage);
        final String processedPath =
            imagePath.replaceAll('.jpg', '_enhanced.jpg');
        cv.imwrite(processedPath, enhanced);

        return processedPath;
      }
    } catch (e) {
      print('❌ Erreur traitement OpenCV: $e');
      return imagePath; // Retourner l'image originale en cas d'erreur
    }
  }

  /// Redimensionne l'image en gardant le ratio
  static cv.Mat _resizeImage(cv.Mat image, int maxSize) {
    if (image.cols <= maxSize && image.rows <= maxSize) {
      return image.clone();
    }

    double scale;
    if (image.cols > image.rows) {
      scale = maxSize / image.cols;
    } else {
      scale = maxSize / image.rows;
    }

    final newWidth = (image.cols * scale).round();
    final newHeight = (image.rows * scale).round();

    return cv.resize(image, (newWidth, newHeight));
  }

  /// Trouve les coins du document dans l'image
  static List<cv.Point2f> _findDocumentCorners(cv.Mat edges) {
    try {
      // Trouver les contours
      final result =
          cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      final contours = result.$1; // Accès au premier élément du tuple

      if (contours.isEmpty) return [];

      // Convertir en liste pour pouvoir trier
      final contoursList = <cv.VecPoint>[];
      for (int i = 0; i < contours.length; i++) {
        contoursList.add(contours[i]);
      }

      // Trier les contours par aire (le plus grand en premier)
      contoursList
          .sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

      // Chercher le premier contour rectangulaire
      for (int i = 0; i < math.min(contoursList.length, 5); i++) {
        final contour = contoursList[i];
        final area = cv.contourArea(contour);
        final perimeter = cv.arcLength(contour, true);

        // Ignorer les contours trop petits
        if (area < 1000) continue;

        // Approximation polygonale
        final approx = cv.approxPolyDP(contour, 0.02 * perimeter, true);

        // Chercher un quadrilatère
        if (approx.length == 4) {
          print('📐 Quadrilatère trouvé avec aire: $area');

          // Convertir en points 2D
          final corners = <cv.Point2f>[];
          for (int j = 0; j < approx.length; j++) {
            final point = approx[j]; // Accès direct par index
            corners.add(cv.Point2f(point.x.toDouble(), point.y.toDouble()));
          }

          // Ordonner les coins (haut-gauche, haut-droite, bas-droite, bas-gauche)
          return _orderCorners(corners);
        }
      }

      return [];
    } catch (e) {
      print('❌ Erreur détection coins: $e');
      return [];
    }
  }

  /// Ordonne les coins dans le sens horaire à partir du haut-gauche
  static List<cv.Point2f> _orderCorners(List<cv.Point2f> corners) {
    // Calculer le centre des points
    final centerX =
        corners.map((p) => p.x).reduce((a, b) => a + b) / corners.length;
    final centerY =
        corners.map((p) => p.y).reduce((a, b) => a + b) / corners.length;

    cv.Point2f? topLeft, topRight, bottomLeft, bottomRight;

    // Classer les points selon leur position relative au centre
    for (final corner in corners) {
      if (corner.x < centerX && corner.y < centerY) {
        topLeft = corner; // Haut-gauche
      } else if (corner.x > centerX && corner.y < centerY) {
        topRight = corner; // Haut-droite
      } else if (corner.x < centerX && corner.y > centerY) {
        bottomLeft = corner; // Bas-gauche
      } else if (corner.x > centerX && corner.y > centerY) {
        bottomRight = corner; // Bas-droite
      }
    }

    // Retourner dans l'ordre correct pour éviter l'inversion
    return [
      topLeft ?? corners[0],
      topRight ?? corners[1],
      bottomRight ?? corners[2],
      bottomLeft ?? corners[3],
    ];
  }

  /// Applique la correction de perspective
  static cv.Mat _perspectiveCorrection(cv.Mat image, List<cv.Point2f> corners) {
    try {
      // Calculer les dimensions du rectangle de destination
      final topWidth = _distance(corners[0], corners[1]);
      final bottomWidth = _distance(corners[2], corners[3]);
      final leftHeight = _distance(corners[0], corners[3]);
      final rightHeight = _distance(corners[1], corners[2]);

      final maxWidth = math.max(topWidth, bottomWidth).round();
      final maxHeight = math.max(leftHeight, rightHeight).round();

      print('📏 Dimensions cible: ${maxWidth}x$maxHeight');

      // Points de destination (rectangle parfait)
      final dst = [
        cv.Point2f(0, 0), // Haut-gauche
        cv.Point2f(maxWidth.toDouble(), 0), // Haut-droite
        cv.Point2f(maxWidth.toDouble(), maxHeight.toDouble()), // Bas-droite
        cv.Point2f(0, maxHeight.toDouble()), // Bas-gauche
      ];

      // Convertir les Point2f en Points normaux pour getPerspectiveTransform
      final srcPoints =
          corners.map((p) => cv.Point(p.x.round(), p.y.round())).toList();
      final dstPoints =
          dst.map((p) => cv.Point(p.x.round(), p.y.round())).toList();

      // Convertir en VecPoint
      final srcVec = cv.VecPoint.fromList(srcPoints);
      final dstVec = cv.VecPoint.fromList(dstPoints);

      // Calculer la matrice de transformation perspective
      final transformMatrix = cv.getPerspectiveTransform(srcVec, dstVec);

      // Appliquer la transformation
      final corrected = cv.warpPerspective(
        image,
        transformMatrix,
        (maxWidth, maxHeight),
      );

      return corrected;
    } catch (e) {
      print('❌ Erreur correction perspective: $e');
      return image.clone();
    }
  }

  /// Corrige l'orientation de l'image (effet miroir si nécessaire)
  static cv.Mat _correctOrientation(cv.Mat image) {
    try {
      // Pour l'instant, on teste en retournant horizontalement
      // Dans une version avancée, on pourrait analyser le texte pour détecter l'orientation

      // Test simple : si l'image semble inversée, on la retourne
      // Ici on pourrait ajouter une logique de détection du texte
      // Pour l'instant, on retourne l'image telle quelle
      // Si l'utilisateur signale que c'est inversé, on peut ajouter un flip

      return image.clone();
    } catch (e) {
      print('❌ Erreur correction orientation: $e');
      return image.clone();
    }
  }

  /// Retourne l'image horizontalement (effet miroir)
  static Future<String> flipImageHorizontally(String imagePath) async {
    try {
      final cv.Mat image = cv.imread(imagePath);
      if (image.isEmpty) return imagePath;

      final cv.Mat flipped = cv.flip(image, 1); // 1 = flip horizontal

      final String flippedPath = imagePath.replaceAll('.jpg', '_flipped.jpg');
      cv.imwrite(flippedPath, flipped);

      print('🔄 Image retournée: $flippedPath');
      return flippedPath;
    } catch (e) {
      print('❌ Erreur flip: $e');
      return imagePath;
    }
  }

  /// Calcule la distance entre deux points
  static double _distance(cv.Point2f p1, cv.Point2f p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Améliore la qualité du document en gardant la couleur
  static cv.Mat _enhanceDocument(cv.Mat image) {
    try {
      print('🎨 Amélioration en couleur...');

      // Garder l'image en couleur
      cv.Mat enhanced = image.clone();

      // 1. Améliorer le contraste et la luminosité
      enhanced = cv.convertScaleAbs(enhanced, alpha: 1.2, beta: 15);

      // 2. Appliquer un filtre de netteté léger
      final sharpKernel = cv.Mat.fromList(3, 3, cv.MatType.CV_32FC1,
          [0.0, -1.0, 0.0, -1.0, 5.0, -1.0, 0.0, -1.0, 0.0]);

      final sharpened = cv.filter2D(enhanced, -1, sharpKernel);

      // 3. Mélanger avec l'image originale pour un effet subtil
      final result = cv.addWeighted(enhanced, 0.7, sharpened, 0.3, 0);

      print('✅ Amélioration couleur terminée');
      return result;
    } catch (e) {
      print('❌ Erreur amélioration: $e');
      return image.clone();
    }
  }

  /// Convertit l'image en noir et blanc avec seuillage adaptatif
  static Future<String> convertToBlackAndWhite(String imagePath) async {
    try {
      print('⚫ Conversion noir et blanc...');

      final cv.Mat image = cv.imread(imagePath);
      if (image.isEmpty) return imagePath;

      // Convertir en niveaux de gris
      final cv.Mat gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);

      // Appliquer un seuillage adaptatif pour un meilleur résultat
      final cv.Mat binary = cv.adaptiveThreshold(
        gray,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        11,
        2,
      );

      // Sauvegarder
      final String bwPath = imagePath.replaceAll('.jpg', '_bw.jpg');
      cv.imwrite(bwPath, binary);

      print('✅ Conversion terminée: $bwPath');
      return bwPath;
    } catch (e) {
      print('❌ Erreur conversion N&B: $e');
      return imagePath;
    }
  }
}
