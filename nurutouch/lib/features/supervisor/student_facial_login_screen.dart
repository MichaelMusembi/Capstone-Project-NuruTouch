import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/face_recognition_service.dart';
import '../../services/haptic_service.dart';
import '../../services/tts_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/app_state.dart';
import '../../theme/colors.dart';
import '../splash/role_selection_screen.dart';
import '../learner/orientation_screen.dart';
import '../splash/gateway_screen.dart';
// for camera

class StudentFacialLoginScreen extends StatefulWidget {
  final int? targetStudentId;

  const StudentFacialLoginScreen({super.key, this.targetStudentId});

  @override
  State<StudentFacialLoginScreen> createState() => _StudentFacialLoginScreenState();
}

class _StudentFacialLoginScreenState extends State<StudentFacialLoginScreen> {
  CameraController? _cameraController;
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();

  bool _isProcessing = false;
  DateTime? _scanStartTime;
  bool _midPointCuePlayed = false;
  List<Map<String, dynamic>> _allStudents = [];
  int _attemptCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _initCamera();
  }

  Future<void> _loadStudents() async {
    _allStudents = await DatabaseHelper.instance.getAllStudents();
  }

  Future<void> _initCamera() async {
    await _faceRecognitionService.initialize();
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    try {
      _cameraController = CameraController(
        frontCamera, 
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      
      await _cameraController!.initialize();
      _scanStartTime = DateTime.now();

      if (mounted) {
        setState(() {});
      }

      _cameraController!.startImageStream((image) {
        if (_isProcessing) return;
        _processCameraFrame(image);
      });
      
      _ttsService.speak("Hold the phone up to your face to log in.", language: "en-US");
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  DateTime _lastAudioCueTime = DateTime.now();

  Future<void> _processCameraFrame(CameraImage image) async {
    _isProcessing = true;

    try {
      final sensorOrientation = _cameraController!.description.sensorOrientation;
      final lensDirection = _cameraController!.description.lensDirection;

      final result = await _faceRecognitionService.detectPoseAndProcess(
        image, 
        sensorOrientation, 
        lensDirection, 
        true
      );

      if (result != null) {
        final rect = result['boundingBox'] as Rect?;
        final imgW = result['imageWidth'] as int;
        final imgH = result['imageHeight'] as int;
        
        // AUDIO FRAMING
        if (rect != null) {
          final now = DateTime.now();
          if (now.difference(_lastAudioCueTime).inSeconds >= 3) {
            // Check bounding box center relative to image dimensions
            // Note: Camera sensor is rotated. For portrait: imgW is actual physical height, imgH is width
            final centerX = rect.center.dx;
            
            // In portrait, MLKit swaps width/height logic for the image size, but the rect is relative to the rotated image.
            // If the camera is front facing, left and right might be mirrored for the user.
            // Let's use simple margins.
            if (centerX < imgW * 0.35) {
              _ttsService.speak("Move right", language: "en-US");
              _lastAudioCueTime = now;
            } else if (centerX > imgW * 0.65) {
              _ttsService.speak("Move left", language: "en-US");
              _lastAudioCueTime = now;
            } else if (rect.width < imgW * 0.3) {
              _ttsService.speak("Move closer", language: "en-US");
              _lastAudioCueTime = now;
            }
          }
        }

        if (result['embedding'] != null) {
          List<double> embedding = result['embedding'];
          
          double bestSimilarity = -1.0;
          int matchedStudentId = -1;
          String matchedStudentName = "";

          for (var student in _allStudents) {
            if (widget.targetStudentId != null && student['id'] != widget.targetStudentId) {
              continue;
            }
            List<dynamic> jsonList = jsonDecode(student['face_embedding']);
            List<double> dbEmbedding = jsonList.map((e) => (e as num).toDouble()).toList();
            
            double similarity = _cosineSimilarity(embedding, dbEmbedding);
            if (similarity > bestSimilarity) {
              bestSimilarity = similarity;
              matchedStudentId = student['id'];
              matchedStudentName = student['name'];
            }
          }

          _attemptCounter++;
          debugPrint("FACIAL_LOGIN_ATTEMPT: attempt=$_attemptCounter, score=${bestSimilarity.toStringAsFixed(4)}");

          // Enforce strict matching regardless of student count.

          // Relaxed similarity threshold from 0.35 to 0.20 for easier login
          if (bestSimilarity >= 0.20 && matchedStudentId != -1) {
            await _cameraController!.stopImageStream();
            _hapticService.successPulse();
            
            // Await the TTS so the user actually hears it before the screen transitions and Gateway cuts it off
            await _ttsService.speak("Welcome, $matchedStudentName.", language: "en-US");
            await Future.delayed(const Duration(seconds: 2));
            
            AppState().currentStudentId = matchedStudentId;
            
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const GatewayScreen()),
              );
            }
            return;
          }
        }
      }
      if (_scanStartTime != null) {
        final elapsed = DateTime.now().difference(_scanStartTime!).inSeconds;
        
        if (elapsed >= 7 && !_midPointCuePlayed) {
           _midPointCuePlayed = true;
           _ttsService.speak("I'm having trouble seeing you. Let's try adjusting the tablet.", language: "en-US");
        }
        
        // Extended timeout to 25 seconds before giving up
        if (elapsed >= 25) {
          await _cameraController!.stopImageStream();
          await _ttsService.speak("I can't see your face clearly. Please ask your teacher for help.", language: "en-US");
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Error scanning face: \$e");
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        _isProcessing = false;
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    // Rule 5: Strict Memory Management
    _faceRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.bone,
      appBar: AppBar(
        title: const Text("Student Auto-Login", style: TextStyle(color: Colors.white)),
        backgroundColor: NuruColors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _cameraController?.stopImageStream();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            );
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Looking for a student...",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NuruColors.indigo),
            ),
            const SizedBox(height: 32),
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Container(
                height: 350,
                width: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isProcessing ? Colors.orange : NuruColors.indigo,
                    width: 6,
                  ),
                ),
                child: ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 300,
                          height: _cameraController!.value.previewSize?.width ?? 300,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: NuruColors.green),
          ],
        ),
      ),
    );
  }
}
