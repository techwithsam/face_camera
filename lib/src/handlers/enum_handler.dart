import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../res/enums.dart';

class EnumHandler {
  static ResolutionPreset imageResolutionToResolutionPreset(
      ImageResolution res) {
    return switch (res) {
      ImageResolution.low => ResolutionPreset.low,
      ImageResolution.medium => ResolutionPreset.medium,
      ImageResolution.high => ResolutionPreset.high,
      ImageResolution.veryHigh => ResolutionPreset.veryHigh,
      ImageResolution.ultraHigh => ResolutionPreset.ultraHigh,
      ImageResolution.max => ResolutionPreset.max,
    };
  }

  static CameraLensDirection? cameraLensToCameraLensDirection(
      CameraLens? lens) {
    return switch (lens) {
      CameraLens.front => CameraLensDirection.front,
      CameraLens.back => CameraLensDirection.back,
      CameraLens.external => CameraLensDirection.external,
      null => null,
    };
  }

  static CameraLens? cameraLensDirectionToCameraLens(
      CameraLensDirection? lens) {
    return switch (lens) {
      CameraLensDirection.front => CameraLens.front,
      CameraLensDirection.back => CameraLens.back,
      CameraLensDirection.external => CameraLens.external,
      null => null,
    };
  }

  static FlashMode cameraFlashModeToFlashMode(CameraFlashMode mode) {
    return switch (mode) {
      CameraFlashMode.off => FlashMode.off,
      CameraFlashMode.auto => FlashMode.auto,
      CameraFlashMode.always => FlashMode.always,
    };
  }

  static DeviceOrientation? cameraOrientationToDeviceOrientation(
      CameraOrientation? orientation) {
    return switch (orientation) {
      CameraOrientation.portraitUp => DeviceOrientation.portraitUp,
      CameraOrientation.landscapeLeft => DeviceOrientation.landscapeLeft,
      CameraOrientation.portraitDown => DeviceOrientation.portraitDown,
      CameraOrientation.landscapeRight => DeviceOrientation.landscapeRight,
      null => null,
    };
  }
}
