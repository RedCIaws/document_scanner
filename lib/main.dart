import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';
import 'theme/app_theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    // Cameras will remain empty if initialization fails
  }

  runApp(const DocumentScannerApp());
}

class DocumentScannerApp extends StatelessWidget {
  const DocumentScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Only Scan',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Only Scan'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.appGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final isSmallScreen = screenHeight < 600;
              
              return Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                child: Column(
                  children: [
                    // Top spacing - smaller on small screens
                    SizedBox(height: isSmallScreen ? 8 : 16),
                    
                    // Welcome Card - adaptive size
                    Expanded(
                      flex: isSmallScreen ? 2 : 3,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isSmallScreen)
                                Icon(
                                  Icons.document_scanner,
                                  size: 60,
                                  color: AppTheme.textPrimary,
                                ),
                              if (!isSmallScreen) const SizedBox(height: 16),
                              Text(
                                'Transformez vos photos en PDF de qualité professionnelle',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 18,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  height: isSmallScreen ? 1.2 : 1.4,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 8 : 16),
                    
                    // Features List - adaptive size
                    Expanded(
                      flex: isSmallScreen ? 2 : 3,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Fonctionnalités',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 12),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _buildFeatureItem(Icons.auto_fix_high, 'Amélioration automatique', isSmallScreen),
                                    _buildFeatureItem(Icons.crop_rotate, 'Correction de perspective', isSmallScreen),
                                    _buildFeatureItem(Icons.picture_as_pdf, 'Export PDF multi-pages', isSmallScreen),
                                    _buildFeatureItem(Icons.share, 'Partage facile', isSmallScreen),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Spacing before button
                    SizedBox(height: isSmallScreen ? 8 : 16),
                  
                    // Main Action Button at bottom
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (cameras.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CameraScreen(cameras: cameras),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aucune caméra disponible')),
                            );
                          }
                        },
                        icon: Icon(Icons.camera_alt, size: isSmallScreen ? 24 : 28),
                        label: Text(
                          'Commencer le scan',
                          style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                        ),
                        style: AppTheme.primaryScanButtonStyle.copyWith(
                          padding: MaterialStateProperty.all(
                            EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 24 : 40,
                              vertical: isSmallScreen ? 12 : 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom spacing
                    SizedBox(height: isSmallScreen ? 8 : 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String text, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 4),
      child: Row(
        children: [
          Icon(
            icon, 
            color: AppTheme.accent, 
            size: isSmallScreen ? 16 : 18,
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
