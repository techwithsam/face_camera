import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face_camera/src/extension/nv21_converter.dart';

import '../models/detected_image.dart';

class FaceIdentifier {
  /// Scans [cameraImage] for faces using a pre-created [faceDetector].
  ///
  /// The caller is responsible for the [faceDetector] lifecycle (create once,
  /// pass here per frame, close in dispose). This avoids creating/destroying
  /// the detector on every camera frame.
  static Future<DetectedFace?> scanImage({
    required CameraImage cameraImage,
    required CameraController? controller,
    required FaceDetector faceDetector,
  }) async {
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final inputImage =
        _inputImageFromCameraImage(cameraImage, controller, orientations);
    if (inputImage == null) return null;

    return _detectFace(visionImage: inputImage, faceDetector: faceDetector);
  }

  static InputImage? _inputImageFromCameraImage(CameraImage image,
      CameraController? controller, Map<DeviceOrientation, int> orientations) {
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    // Validate image format — only bgra8888 is supported on iOS.
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.isEmpty) return null;

    final bytes = Platform.isAndroid
        ? image.getNv21Uint8List()
        : Uint8List.fromList(
            image.planes.fold(
              <int>[],
              (List<int> previousValue, element) =>
                  previousValue..addAll(element.bytes),
            ),
          );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only on Android
        format: Platform.isIOS ? format : InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow, // used only on iOS
      ),
    );
  }

  static Future<DetectedFace?> _detectFace({
    required InputImage visionImage,
    required FaceDetector faceDetector,
  }) async {
    try {
      final List<Face> faces = await faceDetector.processImage(visionImage);
      return _extractFace(faces);
    } catch (error) {
      debugPrint('FaceIdentifier error: $error');
      return null;
    }
  }

  static DetectedFace _extractFace(List<Face> faces) {
    bool wellPositioned = faces.isNotEmpty;
    Face? detectedFace;

    for (final Face face in faces) {
      detectedFace = face;

      // Head rotation checks.
      if ((face.headEulerAngleY ?? 0).abs() > 5) wellPositioned = false;
      if ((face.headEulerAngleZ ?? 0).abs() > 5) wellPositioned = false;

      // Landmark visibility checks.
      final requiredLandmarks = [
        FaceLandmarkType.leftEar,
        FaceLandmarkType.rightEar,
        FaceLandmarkType.bottomMouth,
        FaceLandmarkType.rightMouth,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.noseBase,
      ];
      if (requiredLandmarks.any((t) => face.landmarks[t] == null)) {
        wellPositioned = false;
      }

      // Eye-open probability checks.
      if ((face.leftEyeOpenProbability ?? 1.0) < 0.5) wellPositioned = false;
      if ((face.rightEyeOpenProbability ?? 1.0) < 0.5) wellPositioned = false;

      if (wellPositioned) break;
    }

    return DetectedFace(wellPositioned: wellPositioned, face: detectedFace);
  }
}
