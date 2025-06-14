import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'preview_screen.dart';
import '../services/scan_session.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool isReady = false;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );

    try {
      await controller!.initialize();
      if (mounted) {
        setState(() {
          isReady = true;
        });
      }
    } catch (e) {
      // Camera initialization failed
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!isReady || controller == null || isCapturing) return;

    setState(() {
      isCapturing = true;
    });

    try {
      // Prendre la photo
      final XFile image = await controller!.takePicture();

      // Naviguer vers l'écran de prévisualisation
      if (mounted) {
        // Vérifier si c'est le premier document de la session
        final isFirstDocument = ScanSessionService.getDocumentCount() == 0;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              imagePath: image.path,
              isFirstDocument: isFirstDocument,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la prise de photo')),
      );
    } finally {
      setState(() {
        isCapturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Document'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: isReady && controller != null
          ? Stack(
              children: [
                // Aperçu de la caméra
                Positioned.fill(
                  child: CameraPreview(controller!),
                ),

                // Overlay avec guide visuel
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.6,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Placez le document\ndans ce cadre',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bouton de capture
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCapturing ? Colors.grey : Colors.white,
                          border: Border.all(
                            color: Colors.grey,
                            width: 4,
                          ),
                        ),
                        child: isCapturing
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Initialisation de la caméra...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }
}
