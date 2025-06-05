import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'dart:math' as math;

class ImageProcessingService {
  /// Détecte automatiquement les contours du document et applique la correction de perspective
  static Future<String> processDocument(String imagePath) async {
    try {

      // 1. Charger l'image avec OpenCV
      final cv.Mat originalImage = cv.imread(imagePath);
      if (originalImage.isEmpty) {
        throw Exception('Impossible de charger l\'image');
      }


      // 2. Redimensionner pour le traitement (améliore les performances)
      final cv.Mat resized = _resizeImage(originalImage, 800);
      final double scale = originalImage.cols / resized.cols;

      // 3. Préparation de l'image pour la détection des contours avec seuils adaptatifs
      final cv.Mat gray = cv.cvtColor(resized, cv.COLOR_BGR2GRAY);
      final cv.Mat blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final cv.Mat edges = _adaptiveEdgeDetection(blurred);


      // 4. Détecter les contours du document
      final corners = _findDocumentCorners(edges);

      if (corners.isNotEmpty) {

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

        return processedPath;
      } else {

        // Si pas de document détecté, améliorer l'image originale
        final cv.Mat enhanced = _enhanceDocument(originalImage);
        final String processedPath =
            imagePath.replaceAll('.jpg', '_enhanced.jpg');
        cv.imwrite(processedPath, enhanced);

        return processedPath;
      }
    } catch (e) {
      return imagePath; // Return original image on error
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

  /// Trouve les coins du document avec plusieurs stratégies
  static List<cv.Point2f> _findDocumentCorners(cv.Mat edges) {
    try {
      // Stratégie 1: Détection standard
      List<cv.Point2f> corners = _findCornersStandard(edges);
      if (corners.isNotEmpty && _validateCorners(corners, edges)) {
        return corners;
      }

      // Stratégie 2: Détection avec morphologie
      corners = _findCornersWithMorphology(edges);
      if (corners.isNotEmpty && _validateCorners(corners, edges)) {
        return corners;
      }

      // Stratégie 3: Détection relaxée
      corners = _findCornersRelaxed(edges);
      if (corners.isNotEmpty && _validateCorners(corners, edges)) {
        return corners;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Stratégie de détection standard
  static List<cv.Point2f> _findCornersStandard(cv.Mat edges) {
    final result = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
    final contours = result.$1;
    if (contours.isEmpty) return [];

    final contoursList = <cv.VecPoint>[];
    for (int i = 0; i < contours.length; i++) {
      contoursList.add(contours[i]);
    }

    contoursList.sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

    for (int i = 0; i < math.min(contoursList.length, 8); i++) {
      final contour = contoursList[i];
      final area = cv.contourArea(contour);
      final perimeter = cv.arcLength(contour, true);

      // Seuil adaptatif basé sur la taille de l'image
      final imageArea = edges.rows * edges.cols;
      final minArea = imageArea * 0.1; // Au moins 10% de l'image

      if (area < minArea) continue;

      // Essayer différents epsilon pour l'approximation
      for (double epsilon in [0.01, 0.02, 0.03, 0.04]) {
        final approx = cv.approxPolyDP(contour, epsilon * perimeter, true);
        
        if (approx.length == 4) {
          final corners = <cv.Point2f>[];
          for (int j = 0; j < approx.length; j++) {
            final point = approx[j];
            corners.add(cv.Point2f(point.x.toDouble(), point.y.toDouble()));
          }
          
          final orderedCorners = _orderCornersAdvanced(corners);
          if (_isValidRectangle(orderedCorners)) {
            return orderedCorners;
          }
        }
      }
    }
    return [];
  }

  /// Stratégie avec opérations morphologiques
  static List<cv.Point2f> _findCornersWithMorphology(cv.Mat edges) {
    // Appliquer des opérations morphologiques pour nettoyer les contours
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    final cleaned = cv.morphologyEx(edges, cv.MORPH_CLOSE, kernel);
    final dilated = cv.dilate(cleaned, kernel, iterations: 1);
    
    return _findCornersStandard(dilated);
  }

  /// Stratégie relaxée pour les cas difficiles
  static List<cv.Point2f> _findCornersRelaxed(cv.Mat edges) {
    final result = cv.findContours(edges, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    final contours = result.$1;
    if (contours.isEmpty) return [];

    final contoursList = <cv.VecPoint>[];
    for (int i = 0; i < contours.length; i++) {
      contoursList.add(contours[i]);
    }

    contoursList.sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

    // Essayer de combiner plusieurs contours ou utiliser des seuils plus bas
    for (int i = 0; i < math.min(contoursList.length, 15); i++) {
      final contour = contoursList[i];
      final area = cv.contourArea(contour);
      final perimeter = cv.arcLength(contour, true);

      final imageArea = edges.rows * edges.cols;
      final minArea = imageArea * 0.05; // Seuil plus bas: 5% de l'image

      if (area < minArea) continue;

      for (double epsilon in [0.005, 0.015, 0.025, 0.035, 0.05]) {
        final approx = cv.approxPolyDP(contour, epsilon * perimeter, true);
        
        if (approx.length == 4) {
          final corners = <cv.Point2f>[];
          for (int j = 0; j < approx.length; j++) {
            final point = approx[j];
            corners.add(cv.Point2f(point.x.toDouble(), point.y.toDouble()));
          }
          
          return _orderCornersAdvanced(corners);
        }
      }
    }
    return [];
  }

  /// Valide si les coins détectés forment un document valide
  static bool _validateCorners(List<cv.Point2f> corners, cv.Mat edges) {
    if (corners.length != 4) return false;
    
    // Vérifier que les coins forment un quadrilatère convexe
    if (!_isValidRectangle(corners)) return false;
    
    // Vérifier que le rectangle couvre une partie significative de l'image
    final area = _calculatePolygonArea(corners);
    final imageArea = edges.rows * edges.cols;
    final coverageRatio = area / imageArea;
    
    return coverageRatio >= 0.1 && coverageRatio <= 0.95;
  }

  /// Vérifie si les points forment un rectangle valide
  static bool _isValidRectangle(List<cv.Point2f> corners) {
    if (corners.length != 4) return false;
    
    // Calculer les distances entre coins adjacents
    final distances = <double>[];
    for (int i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      distances.add(_distance(corners[i], corners[next]));
    }
    
    // Vérifier que les côtés opposés ont des longueurs similaires
    final ratio1 = math.min(distances[0], distances[2]) / math.max(distances[0], distances[2]);
    final ratio2 = math.min(distances[1], distances[3]) / math.max(distances[1], distances[3]);
    
    return ratio1 > 0.5 && ratio2 > 0.5; // Tolérance pour les rectangles déformés
  }

  /// Calcule l'aire d'un polygone
  static double _calculatePolygonArea(List<cv.Point2f> points) {
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].x * points[j].y;
      area -= points[j].x * points[i].y;
    }
    return area.abs() / 2.0;
  }

  /// Ordonne les coins avec une méthode avancée basée sur les distances
  static List<cv.Point2f> _orderCornersAdvanced(List<cv.Point2f> corners) {
    if (corners.length != 4) return corners;

    // Calculer la somme et différence de coordonnées pour chaque point
    final pointsWithData = corners.map((p) => {
      'point': p,
      'sum': p.x + p.y,
      'diff': p.x - p.y,
    }).toList();

    // Trier par somme pour trouver top-left (plus petite) et bottom-right (plus grande)
    pointsWithData.sort((a, b) => (a['sum'] as double).compareTo(b['sum'] as double));
    final topLeft = pointsWithData.first['point'] as cv.Point2f;
    final bottomRight = pointsWithData.last['point'] as cv.Point2f;

    // Trier par différence pour trouver top-right et bottom-left
    pointsWithData.sort((a, b) => (a['diff'] as double).compareTo(b['diff'] as double));
    final bottomLeft = pointsWithData.first['point'] as cv.Point2f;
    final topRight = pointsWithData.last['point'] as cv.Point2f;

    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  /// Ordonne les coins dans le sens horaire à partir du haut-gauche (méthode simple de fallback)
  static List<cv.Point2f> _orderCorners(List<cv.Point2f> corners) {
    return _orderCornersAdvanced(corners);
  }

  /// Détection de contours adaptative avec seuils calculés automatiquement
  static cv.Mat _adaptiveEdgeDetection(cv.Mat grayImage) {
    try {
      // Calculer les statistiques de l'image pour des seuils adaptatifs
      final stats = cv.meanStdDev(grayImage);
      final mean = stats.$1.val1; // Moyenne
      final stdDev = stats.$2.val1; // Écart-type

      // Calculer les seuils basés sur les statistiques de l'image
      final sigma = 0.33;
      final median = mean; // Approximation de la médiane avec la moyenne
      final lower = math.max(0, (1.0 - sigma) * median).round();
      final upper = math.min(255, (1.0 + sigma) * median).round();


      // Appliquer Canny avec les seuils calculés
      cv.Mat edges = cv.canny(grayImage, lower.toDouble(), upper.toDouble());

      // Si les seuils adaptatifs ne donnent pas de bons résultats, essayer d'autres approches
      final contourResult = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      final contours = contourResult.$1;

      if (contours.isEmpty || contours.length < 3) {
        
        // Essayer avec des seuils plus conservateurs
        edges = cv.canny(grayImage, 50, 150);
        
        final retryResult = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
        if (retryResult.$1.isEmpty) {
          // Dernier recours avec seuils larges
          edges = cv.canny(grayImage, 30, 200);
        }
      }

      return edges;
    } catch (e) {
      // Fallback to classic Canny
      return cv.canny(grayImage, 75, 200);
    }
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

      return flippedPath;
    } catch (e) {
      return imagePath;
    }
  }

  /// Calcule la distance entre deux points
  static double _distance(cv.Point2f p1, cv.Point2f p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Améliore la qualité du document avec analyse adaptative
  static cv.Mat _enhanceDocument(cv.Mat image) {
    try {

      // Analyser les caractéristiques de l'image
      final imageStats = _analyzeImageCharacteristics(image);

      cv.Mat enhanced = image.clone();

      // 1. Correction adaptative de la luminosité et du contraste
      enhanced = _adaptiveBrightnessContrast(enhanced, imageStats);

      // 2. Correction des ombres si nécessaire
      if (imageStats['hasShadows'] == true) {
        enhanced = _shadowCorrection(enhanced);
      }

      // 3. Amélioration de la netteté adaptative
      enhanced = _adaptiveSharpening(enhanced, imageStats);

      // 4. Réduction du bruit si nécessaire
      if (imageStats['hasNoise'] == true) {
        enhanced = _noiseReduction(enhanced);
      }

      // 5. Amélioration finale du contraste
      enhanced = _enhanceContrast(enhanced);

      return enhanced;
    } catch (e) {
      return _basicEnhancement(image);
    }
  }

  /// Analyse les caractéristiques de l'image pour l'amélioration adaptative
  static Map<String, dynamic> _analyzeImageCharacteristics(cv.Mat image) {
    try {
      // Convertir en niveaux de gris pour l'analyse
      final cv.Mat gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
      
      // Calculer les statistiques de base
      final stats = cv.meanStdDev(gray);
      final brightness = stats.$1.val1; // Moyenne = luminosité
      final contrast = stats.$2.val1; // Écart-type = contraste

      // Détecter les ombres (zones très sombres)
      final cv.Mat darkMask = cv.threshold(gray, 50, 255, cv.THRESH_BINARY_INV).$2;
      final darkPixels = cv.countNonZero(darkMask);
      final totalPixels = gray.rows * gray.cols;
      final shadowRatio = darkPixels / totalPixels;
      final hasShadows = shadowRatio > 0.15; // Plus de 15% de pixels sombres

      // Détecter le bruit (variations haute fréquence)
      final laplacian = cv.laplacian(gray, cv.MatType.CV_64F);
      final laplacianStats = cv.meanStdDev(laplacian);
      final laplacianVariance = laplacianStats.$2.val1;
      final hasNoise = laplacianVariance > 500; // Seuil empirique pour le bruit

      return {
        'brightness': brightness,
        'contrast': contrast,
        'hasShadows': hasShadows,
        'shadowRatio': shadowRatio,
        'hasNoise': hasNoise,
        'noiseLevel': laplacianVariance,
      };
    } catch (e) {
      return {
        'brightness': 128.0,
        'contrast': 50.0,
        'hasShadows': false,
        'hasNoise': false,
      };
    }
  }

  /// Correction adaptative de la luminosité et du contraste
  static cv.Mat _adaptiveBrightnessContrast(cv.Mat image, Map<String, dynamic> stats) {
    final brightness = stats['brightness'] as double;
    final contrast = stats['contrast'] as double;

    // Calculer les paramètres adaptatifs
    double alpha = 1.0; // Facteur de contraste
    double beta = 0.0; // Facteur de luminosité

    // Ajuster le contraste de manière plus conservative
    if (contrast < 20) {
      alpha = 1.3; // Augmentation modérée pour images très fades
    } else if (contrast < 40) {
      alpha = 1.15; // Légère amélioration pour images fades
    } else if (contrast > 80) {
      alpha = 0.95; // Réduction très légère pour images très contrastées
    } else {
      alpha = 1.05; // Amélioration très subtile pour préserver le texte
    }

    // Ajuster la luminosité de manière plus douce
    if (brightness < 60) {
      beta = 20; // Éclaircir modérément les images très sombres
    } else if (brightness < 100) {
      beta = 10; // Légère amélioration pour images sombres
    } else if (brightness > 200) {
      beta = -10; // Assombrir légèrement les images trop claires
    } else {
      beta = 5; // Amélioration très subtile
    }

    return cv.convertScaleAbs(image, alpha: alpha, beta: beta);
  }

  /// Correction des ombres
  static cv.Mat _shadowCorrection(cv.Mat image) {
    try {
      // Utiliser HSV au lieu de LAB pour la correction des ombres
      final cv.Mat hsv = cv.cvtColor(image, cv.COLOR_BGR2HSV);
      final channels = cv.split(hsv);
      
      // Appliquer CLAHE plus doux sur le canal V (valeur/luminosité)
      final clahe = cv.createCLAHE(clipLimit: 1.5, tileGridSize: (8, 8));
      final enhancedV = clahe.apply(channels[2]);
      
      // Recombiner les canaux
      final enhancedChannels = cv.VecMat.fromList([channels[0], channels[1], enhancedV]);
      final enhancedHsv = cv.merge(enhancedChannels);
      
      return cv.cvtColor(enhancedHsv, cv.COLOR_HSV2BGR);
    } catch (e) {
      return image.clone();
    }
  }

  /// Amélioration de la netteté adaptative
  static cv.Mat _adaptiveSharpening(cv.Mat image, Map<String, dynamic> stats) {
    try {
      final hasNoise = stats['hasNoise'] as bool;
      
      cv.Mat kernel;
      double weight;
      
      if (hasNoise) {
        // Netteté très douce pour les images bruitées
        kernel = cv.Mat.fromList(3, 3, cv.MatType.CV_32FC1,
            [0.0, -0.25, 0.0, -0.25, 2.0, -0.25, 0.0, -0.25, 0.0]);
        weight = 0.15;
      } else {
        // Netteté modérée pour préserver le texte
        kernel = cv.Mat.fromList(3, 3, cv.MatType.CV_32FC1,
            [0.0, -0.5, 0.0, -0.5, 3.0, -0.5, 0.0, -0.5, 0.0]);
        weight = 0.2;
      }
      
      final sharpened = cv.filter2D(image, -1, kernel);
      return cv.addWeighted(image, 1.0 - weight, sharpened, weight, 0);
    } catch (e) {
      return image.clone();
    }
  }

  /// Réduction du bruit
  static cv.Mat _noiseReduction(cv.Mat image) {
    try {
      // Utiliser un filtre bilatéral pour préserver les contours tout en réduisant le bruit
      return cv.bilateralFilter(image, 9, 75, 75);
    } catch (e) {
      return image.clone();
    }
  }

  /// Amélioration finale du contraste
  static cv.Mat _enhanceContrast(cv.Mat image) {
    try {
      // Convertir en niveaux de gris pour l'amélioration du contraste
      final cv.Mat gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
      
      // Appliquer CLAHE très doux sur l'image en niveaux de gris
      final clahe = cv.createCLAHE(clipLimit: 1.2, tileGridSize: (8, 8));
      final enhancedGray = clahe.apply(gray);
      
      // Convertir back en BGR et mélanger très subtilement avec l'original
      final cv.Mat enhancedBgr = cv.cvtColor(enhancedGray, cv.COLOR_GRAY2BGR);
      
      // Mélanger avec plus de poids sur l'original pour préserver le texte
      return cv.addWeighted(image, 0.8, enhancedBgr, 0.2, 0);
    } catch (e) {
      return image.clone();
    }
  }

  /// Amélioration de base en cas d'erreur (très conservative)
  static cv.Mat _basicEnhancement(cv.Mat image) {
    try {
      cv.Mat enhanced = image.clone();
      // Paramètres plus conservateurs pour préserver le texte
      enhanced = cv.convertScaleAbs(enhanced, alpha: 1.1, beta: 8);
      
      final sharpKernel = cv.Mat.fromList(3, 3, cv.MatType.CV_32FC1,
          [0.0, -0.5, 0.0, -0.5, 3.0, -0.5, 0.0, -0.5, 0.0]);
      final sharpened = cv.filter2D(enhanced, -1, sharpKernel);
      
      // Moins de netteté pour éviter les artefacts
      return cv.addWeighted(enhanced, 0.85, sharpened, 0.15, 0);
    } catch (e) {
      return image.clone();
    }
  }

  /// Convertit l'image en noir et blanc avec seuillage adaptatif
  static Future<String> convertToBlackAndWhite(String imagePath) async {
    try {

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

      return bwPath;
    } catch (e) {
      return imagePath;
    }
  }
}
