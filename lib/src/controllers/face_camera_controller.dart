import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../face_camera.dart';
import '../handlers/enum_handler.dart';
import '../handlers/face_identifier.dart';
import '../utils/logger.dart';
import 'face_camera_state.dart';

/// The controller for the [SmartFaceCamera] widget.
class FaceCameraController extends ValueNotifier<FaceCameraState> {
  /// Construct a new [FaceCameraController] instance.
  FaceCameraController({
    this.imageResolution = ImageResolution.medium,
    this.defaultCameraLens,
    this.defaultFlashMode = CameraFlashMode.auto,
    this.enableAudio = true,
    this.autoCapture = false,
    this.ignoreFacePositioning = false,
    this.orientation = CameraOrientation.portraitUp,
    this.performanceMode = FaceDetectorMode.fast,
    required this.onCapture,
    this.onFaceDetected,
  }) : super(FaceCameraState.uninitialized());

  /// The desired resolution for the camera.
  final ImageResolution imageResolution;

  /// Use this to set initial camera lens direction.
  final CameraLens? defaultCameraLens;

  /// Use this to set initial flash mode.
  final CameraFlashMode defaultFlashMode;

  /// Set false to disable capture sound.
  final bool enableAudio;

  /// Set true to capture image on face detected.
  final bool autoCapture;

  /// Set true to trigger [onCapture] even when the face is not well positioned.
  final bool ignoreFacePositioning;

  /// Use this to lock camera orientation.
  final CameraOrientation? orientation;

  /// Use this to set your preferred face-detection performance mode.
  final FaceDetectorMode performanceMode;

  /// Callback invoked when camera captures an image.
  final void Function(File? image) onCapture;

  /// Callback invoked when the camera detects a face.
  final void Function(Face? face)? onFaceDetected;

  /// Single cached detector — created in [initialize], closed in [dispose].
  FaceDetector? _faceDetector;

  // ── Camera lens helpers ────────────────────────────────────────────────────

  void _getAllAvailableCameraLens() {
    int currentCameraLens = 0;
    final List<CameraLens> availableCameraLens = [];
    for (final CameraDescription d in FaceCamera.cameras) {
      final lens = EnumHandler.cameraLensDirectionToCameraLens(d.lensDirection);
      if (lens != null && !availableCameraLens.contains(lens)) {
        availableCameraLens.add(lens);
      }
    }

    if (defaultCameraLens != null) {
      final idx = availableCameraLens.indexOf(defaultCameraLens!);
      if (idx != -1) currentCameraLens = idx;
    }

    value = value.copyWith(
        availableCameraLens: availableCameraLens,
        currentCameraLens: currentCameraLens);
  }

  Future<void> _initCamera() async {
    final cameras = FaceCamera.cameras
        .where((c) =>
            c.lensDirection ==
            EnumHandler.cameraLensToCameraLensDirection(
                value.availableCameraLens[value.currentCameraLens]))
        .toList();

    if (cameras.isEmpty) return;

    final cameraController = CameraController(
      cameras.first,
      EnumHandler.imageResolutionToResolutionPreset(imageResolution),
      enableAudio: enableAudio,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await cameraController.initialize();
    value =
        value.copyWith(isInitialized: true, cameraController: cameraController);

    await changeFlashMode(value.availableFlashMode.indexOf(defaultFlashMode));
    await cameraController.lockCaptureOrientation(
        EnumHandler.cameraOrientationToDeviceOrientation(orientation));

    startImageStream();
  }

  // ── Public controls ────────────────────────────────────────────────────────

  Future<void> changeFlashMode([int? index]) async {
    final newIndex =
        index ?? (value.currentFlashMode + 1) % value.availableFlashMode.length;
    await value.cameraController!
        .setFlashMode(EnumHandler.cameraFlashModeToFlashMode(
            value.availableFlashMode[newIndex]));
    value = value.copyWith(currentFlashMode: newIndex);
  }

  /// The supplied [zoom] value should be between 1.0 and the maximum supported.
  Future<void> setZoomLevel(double zoom) async {
    final cameraController = value.cameraController;
    if (cameraController == null) return;
    await cameraController.setZoomLevel(zoom);
  }

  Future<void> changeCameraLens() async {
    value = value.copyWith(
        currentCameraLens:
            (value.currentCameraLens + 1) % value.availableCameraLens.length);
    await _initCamera();
  }

  Future<XFile?> takePicture() async {
    final cameraController = value.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      logError('Error: select a camera first.');
      return null;
    }
    if (cameraController.value.isTakingPicture) {
      logError('A capture is already pending.');
      return null;
    }
    try {
      return await cameraController.takePicture();
    } on CameraException catch (e) {
      logError(e.code, e.description);
      return null;
    }
  }

  Future<void> startImageStream() async {
    final cameraController = value.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (!cameraController.value.isStreamingImages) {
      await cameraController.startImageStream(_processImage);
    }
  }

  Future<void> stopImageStream() async {
    final cameraController = value.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (cameraController.value.isStreamingImages) {
      await cameraController.stopImageStream();
    }
  }

  void captureImage() {
    final cameraController = value.cameraController;
    if (cameraController == null) {
      logError('captureImage called before camera was initialised.');
      return;
    }
    cameraController.stopImageStream().then((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      final file = await takePicture();
      if (file != null) {
        onCapture.call(File(file.path));
      }
    }).catchError((Object e) {
      logError(e.toString());
    });
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: performanceMode,
      ),
    );
    _getAllAvailableCameraLens();
    await _initCamera();
  }

  /// Enables controls only when the camera is fully initialised.
  bool get enableControls {
    final cameraController = value.cameraController;
    return cameraController != null && cameraController.value.isInitialized;
  }

  @override
  Future<void> dispose() async {
    final cameraController = value.cameraController;
    if (cameraController != null && cameraController.value.isInitialized) {
      await cameraController.dispose();
    }
    await _faceDetector?.close();
    super.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _processImage(CameraImage cameraImage) async {
    final detector = _faceDetector;
    if (detector == null || value.alreadyCheckingImage) return;

    value = value.copyWith(alreadyCheckingImage: true);
    try {
      final result = await FaceIdentifier.scanImage(
        cameraImage: cameraImage,
        controller: value.cameraController,
        faceDetector: detector,
      );

      value = value.copyWith(detectedFace: result);

      if (result != null) {
        if (result.face != null) {
          onFaceDetected?.call(result.face);
        }
        if (autoCapture && (result.wellPositioned || ignoreFacePositioning)) {
          captureImage();
        }
      }
    } catch (ex, stack) {
      logError('$ex\n$stack');
    } finally {
      value = value.copyWith(alreadyCheckingImage: false);
    }
  }
}
