import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

img.Image? _processImageIsolate(Map<String, dynamic> params) {
  final List<dynamic> planesData = params['planes'];
  final int width = params['width'];
  final int height = params['height'];
  final formatGroup = params['formatGroup'];
  final int sensorOrientation = params['sensorOrientation'];
  final CameraLensDirection lensDirection = params['lensDirection'];
  final Map<String, dynamic> boundingBox = params['boundingBox'];

  img.Image? decodedImage;

  if (formatGroup == ImageFormatGroup.yuv420 || formatGroup == ImageFormatGroup.nv21) {
    decodedImage = img.Image(width: width, height: height);
    if (planesData.length == 1) {
      final bytes = planesData[0]['bytes'] as Uint8List;
      final ySize = width * height;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final uvOffset = ySize + (y ~/ 2) * width + (x ~/ 2) * 2;
          final yp = bytes[yIndex];
          int vp = 0;
          int up = 0;
          if (uvOffset < bytes.length) vp = bytes[uvOffset];
          if (uvOffset + 1 < bytes.length) up = bytes[uvOffset + 1];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          decodedImage.setPixelRgb(x, y, r, g, b);
        }
      }
    } else {
      final uvRowStride = planesData[1]['bytesPerRow'] as int;
      final uvPixelStride = planesData[1]['bytesPerPixel'] as int? ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final index = y * (planesData[0]['bytesPerRow'] as int) + x;

          final yp = planesData[0]['bytes'][index];
          int up = 0;
          int vp = 0;

          if (planesData.length == 3) {
            up = planesData[1]['bytes'][uvIndex];
            vp = planesData[2]['bytes'][uvIndex];
          } else if (planesData.length == 2) {
            vp = planesData[1]['bytes'][uvIndex];
            if (uvIndex + 1 < (planesData[1]['bytes'] as Uint8List).length) {
              up = planesData[1]['bytes'][uvIndex + 1];
            }
          }

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          decodedImage.setPixelRgb(x, y, r, g, b);
        }
      }
    }
  } else if (formatGroup == ImageFormatGroup.bgra8888) {
    decodedImage = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: (planesData[0]['bytes'] as Uint8List).buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  if (decodedImage == null) return null;

  decodedImage = img.copyRotate(decodedImage, angle: sensorOrientation);
  int left = max(0, (boundingBox['left'] as double).toInt());
  int top = max(0, (boundingBox['top'] as double).toInt());
  int bw = min(decodedImage.width - left, (boundingBox['width'] as double).toInt());
  int bh = min(decodedImage.height - top, (boundingBox['height'] as double).toInt());

  decodedImage = img.copyCrop(decodedImage, x: left, y: top, width: bw, height: bh);

  if (lensDirection == CameraLensDirection.front) {
    decodedImage = img.flipHorizontal(decodedImage);
  }

  return decodedImage;
}

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  Interpreter? _interpreter;
  FaceDetector? _faceDetector;

  Future<void> initialize() async {
    if (_faceDetector == null) {
      _faceDetector = FaceDetector(options: FaceDetectorOptions(enableContours: false, enableLandmarks: false));
    }
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      debugPrint("FaceRecognitionService initialized successfully.");
    } catch (e) {
      debugPrint("Failed to load model: $e");
    }
  }

  Future<List<double>?> processCameraImage(CameraImage image, int sensorOrientation, CameraLensDirection lensDirection) async {
    // 1. Convert CameraImage to ML Kit InputImage
    final inputImage = await _convertCameraImageToInputImageAsync(image, sensorOrientation, lensDirection);
    if (inputImage == null) return null;

    // 2. Detect Faces
    if (_faceDetector == null) return null;
    final faces = await _faceDetector!.processImage(inputImage);
    if (faces.isEmpty) return null;

    // We take the most prominent face (assuming only one student is looking at the camera)
    final face = faces.first;

    // 3. Convert CameraImage, rotate, and crop using an isolate
    final faceImage = await compute(_processImageIsolate, {
      'planes': image.planes.map((p) => {
        'bytes': p.bytes,
        'bytesPerRow': p.bytesPerRow,
        'bytesPerPixel': p.bytesPerPixel,
      }).toList(),
      'width': image.width,
      'height': image.height,
      'formatGroup': image.format.group,
      'sensorOrientation': sensorOrientation,
      'lensDirection': lensDirection,
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
    });

    if (faceImage == null) return null;

    // 4. Extract embedding
    return extractEmbedding(faceImage);
  }

  Future<Map<String, dynamic>?> detectPoseAndProcess(
    CameraImage image, 
    int sensorOrientation, 
    CameraLensDirection lensDirection,
    bool extractEmbeddingFlag, {
    Function(String)? onDebugMsg,
  }) async {
    final inputImage = await _convertCameraImageToInputImageAsync(image, sensorOrientation, lensDirection);
    if (inputImage == null) {
      onDebugMsg?.call("Unsupported image format");
      return null;
    }

    if (_faceDetector == null) {
      onDebugMsg?.call("FaceDetector not initialized");
      return null;
    }

    final faces = await _faceDetector!.processImage(inputImage);
    if (faces.isEmpty) {
      onDebugMsg?.call("No face detected in frame");
      return null;
    }

    final face = faces.first;

    // Size Validation
    double ratio = face.boundingBox.width / image.width;
    onDebugMsg?.call("Size: ${(ratio*100).toStringAsFixed(1)}% (need 5%), Yaw: ${face.headEulerAngleY?.toStringAsFixed(1) ?? 'null'}");
    
    // RELAXED from 0.15 to 0.05 to allow faces further away
    if (ratio < 0.05) {
      return null;
    }

    List<double>? embedding;
    
    if (extractEmbeddingFlag) {
      // Run heavy image processing in a background isolate to avoid freezing the UI
      final faceImage = await compute(_processImageIsolate, {
        'planes': image.planes.map((p) => {
          'bytes': p.bytes,
          'bytesPerRow': p.bytesPerRow,
          'bytesPerPixel': p.bytesPerPixel,
        }).toList(),
        'width': image.width,
        'height': image.height,
        'formatGroup': image.format.group,
        'sensorOrientation': sensorOrientation,
        'lensDirection': lensDirection,
        'boundingBox': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'width': face.boundingBox.width,
          'height': face.boundingBox.height,
        },
      });
      
      if (faceImage != null) {
        embedding = extractEmbedding(faceImage);
      }
    }

    return {
      'yaw': face.headEulerAngleY,
      'pitch': face.headEulerAngleX,
      'embedding': embedding,
      'boundingBox': face.boundingBox,
      'imageWidth': image.width,
      'imageHeight': image.height,
    };
  }

  Future<List<double>?> processImageFile(String path) async {
    if (_faceDetector == null) return null;
    final inputImage = InputImage.fromFilePath(path);
    final faces = await _faceDetector!.processImage(inputImage);
    if (faces.isEmpty) return null;

    final face = faces.first;
    img.Image? decodedImage = await img.decodeImageFile(path);
    if (decodedImage == null) return null;

    int x = max(0, face.boundingBox.left.toInt());
    int y = max(0, face.boundingBox.top.toInt());
    int w = min(decodedImage.width - x, face.boundingBox.width.toInt());
    int h = min(decodedImage.height - y, face.boundingBox.height.toInt());
    
    img.Image croppedFace = img.copyCrop(decodedImage, x: x, y: y, width: w, height: h);
    return extractEmbedding(croppedFace);
  }

  List<double>? extractEmbedding(img.Image faceImage) {
    if (_interpreter == null) return null;

    // Resize exactly to 112x112 for MobileFaceNet
    img.Image resizedImage = img.copyResize(faceImage, width: 112, height: 112);

    // Normalize to [-1, 1]
    var input = List.generate(1, (i) => List.generate(112, (j) => List.generate(112, (k) => List.filled(3, 0.0))));
    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // Rule 1: Normalization using exact 127.5 divisor
        input[0][y][x][0] = (pixel.r - 127.5) / 127.5;
        input[0][y][x][1] = (pixel.g - 127.5) / 127.5;
        input[0][y][x][2] = (pixel.b - 127.5) / 127.5;
      }
    }

    // Prepare output tensor (usually 192 for MobileFaceNet)
    var outputShape = _interpreter!.getOutputTensor(0).shape;
    var outputSize = outputShape[1];
    var output = List.generate(1, (i) => List.filled(outputSize, 0.0));

    // Run inference
    _interpreter!.run(input, output);

    // Return the embedding vector
    return output[0];
  }

  double compareFaces(List<double> embedding1, List<double> embedding2) {
    // Cosine similarity
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      normA += embedding1[i] * embedding1[i];
      normB += embedding2[i] * embedding2[i];
    }
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  // Rule 5: Strict Memory Management
  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
    _interpreter?.close();
    _interpreter = null;
  }

  // --- Utility functions to convert CameraImage ---

  Future<InputImage?> _convertCameraImageToInputImageAsync(CameraImage image, int sensorOrientation, CameraLensDirection lensDirection) async {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      debugPrint("Unsupported format: ${image.format.raw}");
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // Calculate rotation compensation for ML Kit Android
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // For portrait mode devices, if sensor orientation is 90 or 270.
      // Usually sensorOrientation is enough, but ML Kit rotation expects specific values.
      int rotationCompensation = sensorOrientation;
      if (lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + 0) % 360; // Usually 0 device rotation
      } else {
        rotationCompensation = (sensorOrientation - 0 + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

}
