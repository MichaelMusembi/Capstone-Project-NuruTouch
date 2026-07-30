import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/face_recognition_service.dart';
import '../../services/haptic_service.dart';
import '../../services/tts_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/app_state.dart';
import '../../theme/colors.dart';
import 'dashboard/student_list_screen.dart';
import '../splash/gateway_screen.dart';
// to get cameras if needed, but we can just use availableCameras()

class StudentEnrollmentCameraScreen extends StatefulWidget {
  final String studentName;
  final int studentAge;
  final bool isFirstSetup;

  const StudentEnrollmentCameraScreen({
    super.key,
    required this.studentName,
    required this.studentAge,
    this.isFirstSetup = false,
  });

  @override
  State<StudentEnrollmentCameraScreen> createState() => _StudentEnrollmentCameraScreenState();
}

class _StudentEnrollmentCameraScreenState extends State<StudentEnrollmentCameraScreen> {
  CameraController? _cameraController;
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();

  bool _isProcessing = false;
  int _captureCount = 0;
  List<List<double>> _collectedEmbeddings = [];
  String _debugMsg = "Initializing...";

  int _currentPoseIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
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
        ResolutionPreset.low, 
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});

      _startGuidedCapture();
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startGuidedCapture() {
    _promptForCurrentPose();
    _cameraController!.startImageStream((image) {
      if (_isProcessing) return;
      _processCameraFrame(image);
    });
  }

  void _promptForCurrentPose() {
    if (_currentPoseIndex == 0) {
      _ttsService.speak("Center your face in the frame and stay still.", language: "en-US");
    } else if (_currentPoseIndex == 1) {
      _ttsService.speak("Slowly turn your head to the left.", language: "en-US");
    } else if (_currentPoseIndex == 2) {
      _ttsService.speak("Now, slowly turn your head to the right.", language: "en-US");
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    _isProcessing = true;
    try {
      final sensorOrientation = _cameraController!.description.sensorOrientation;
      final lensDirection = _cameraController!.description.lensDirection;

      final result = await _faceRecognitionService.detectPoseAndProcess(
        image, 
        sensorOrientation, 
        lensDirection, 
        false,
        onDebugMsg: (msg) {
          if (mounted && _debugMsg != msg) {
            setState(() => _debugMsg = msg);
          }
        }
      );

      if (result != null) {
        double? yaw = result['yaw']; // - is left, + is right
        bool poseMatched = false;

        if (yaw != null) {
          if (_currentPoseIndex == 0 && yaw > -12 && yaw < 12) {
            poseMatched = true;
          } else if (_currentPoseIndex == 1 && yaw < -15) { // tuned for easy head turn
            poseMatched = true;
          } else if (_currentPoseIndex == 2 && yaw > 15) {
            poseMatched = true;
          }
        }

        if (poseMatched) {
          _hapticService.successPulse();
          final embResult = await _faceRecognitionService.detectPoseAndProcess(
            image, 
            sensorOrientation, 
            lensDirection, 
            true
          );
          
          if (embResult != null && embResult['embedding'] != null) {
            _collectedEmbeddings.add(embResult['embedding']);
            _currentPoseIndex++;
            _captureCount++;
            
            if (mounted) setState(() {});

            if (_currentPoseIndex < 3) {
              // Add a slight pause before next prompt
              await Future.delayed(const Duration(milliseconds: 500));
              _promptForCurrentPose();
            } else {
              await _cameraController!.stopImageStream();
              await _ttsService.speak("Face registered successfully.", language: "en-US");
              _finalizeEnrollment();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _debugMsg = "Error: $e");
      debugPrint("Error processing frame: $e");
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        _isProcessing = false;
      }
    }
  }

  Future<void> _finalizeEnrollment() async {
    // Average the 3 embeddings
    int embLength = _collectedEmbeddings.first.length;
    List<double> averagedEmbedding = List.filled(embLength, 0.0);
    for (var emb in _collectedEmbeddings) {
      for (int i = 0; i < embLength; i++) {
        averagedEmbedding[i] += emb[i];
      }
    }
    for (int i = 0; i < embLength; i++) {
      averagedEmbedding[i] /= _collectedEmbeddings.length;
    }

    final id = await DatabaseHelper.instance.insertStudent(
      widget.studentName,
      widget.studentAge,
      averagedEmbedding,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student Registered!")));
      
      if (widget.isFirstSetup) {
        // Automatically start their session
        AppState().currentStudentId = id;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GatewayScreen()),
        );
      } else {
        // Return to Dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentListScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.bone,
      appBar: AppBar(
        title: const Text("Face Scan", style: TextStyle(color: Colors.white)),
        backgroundColor: NuruColors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Look directly at the camera",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NuruColors.indigo),
            ),
            const SizedBox(height: 16),
            Text(
              "Scan Progress: $_captureCount / 3",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Text(
              _debugMsg,
              style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
            LinearProgressIndicator(
              value: _captureCount / 3.0,
              backgroundColor: Colors.grey[300],
              color: NuruColors.green,
              minHeight: 12,
            ),
          ],
        ),
      ),
    );
  }
}
