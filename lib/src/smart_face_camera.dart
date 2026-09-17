import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../face_camera.dart';
import 'controllers/face_camera_state.dart';
import 'paints/face_painter.dart';
import 'paints/hole_painter.dart';
import 'res/app_images.dart';
import 'res/builders.dart';

class SmartFaceCamera extends StatefulWidget {
  /// Set false to hide all controls.
  final bool showControls;

  /// Set false to hide capture control icon.
  final bool showCaptureControl;

  /// Set false to hide flash control icon.
  final bool showFlashControl;

  /// Set false to hide camera lens control icon.
  final bool showCameraLensControl;

  /// Use this to pass a message above the camera.
  final String? message;

  /// Style applied to the message widget.
  final TextStyle messageStyle;

  /// Use this to build a custom widget for capture control.
  final CaptureControlBuilder? captureControlBuilder;

  /// Use this to render a custom widget for camera lens control.
  final Widget? lensControlIcon;

  /// Use this to build custom widgets for flash control based on camera flash mode.
  final FlashControlBuilder? flashControlBuilder;

  /// Use this to build custom messages based on face position.
  final MessageBuilder? messageBuilder;

  /// Use this to change the shape of the face indicator.
  final IndicatorShape indicatorShape;

  /// Use this to pass an asset image path when [IndicatorShape] is set to image.
  final String? indicatorAssetImage;

  /// Use this to build a custom widget for the face indicator.
  final IndicatorBuilder? indicatorBuilder;

  /// Set true to automatically disable the capture control when no face is detected.
  final bool autoDisableCaptureControl;

  /// The controller for the [SmartFaceCamera] widget.
  final FaceCameraController controller;

  const SmartFaceCamera({
    required this.controller,
    super.key,
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.message,
    this.messageStyle = const TextStyle(
        fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
    this.captureControlBuilder,
    this.lensControlIcon,
    this.flashControlBuilder,
    this.messageBuilder,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.indicatorAssetImage,
    this.indicatorBuilder,
    this.autoDisableCaptureControl = false,
  }) : assert(
            indicatorShape != IndicatorShape.image ||
                indicatorAssetImage != null,
            'IndicatorAssetImage must be provided when IndicatorShape is set to image.');

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera>
    with WidgetsBindingObserver {
  /// Pre-decoded indicator image (only used when [IndicatorShape.image]).
  ui.Image? _indicatorImage;
  ImageStreamListener? _imageStreamListener;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.initialize();
    _resolveIndicatorImage();
  }

  @override
  void didUpdateWidget(SmartFaceCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.indicatorAssetImage != widget.indicatorAssetImage ||
        oldWidget.indicatorShape != widget.indicatorShape) {
      _resolveIndicatorImage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeImageStreamListener();
    widget.controller.stopImageStream();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        widget.controller.stopImageStream();
        break;
      case AppLifecycleState.resumed:
        widget.controller.startImageStream();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ── Indicator image pre-loading ────────────────────────────────────────────

  void _resolveIndicatorImage() {
    _removeImageStreamListener();
    if (widget.indicatorShape != IndicatorShape.image) return;

    final assetPath = widget.indicatorAssetImage ?? AppImages.faceNet;
    final imageProvider = AssetImage(assetPath);
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() => _indicatorImage = info.image);
      }
    });
    stream.addListener(_imageStreamListener!);
  }

  void _removeImageStreamListener() {
    if (_imageStreamListener != null && _imageStream != null) {
      _imageStream!.removeListener(_imageStreamListener!);
      _imageStream = null;
      _imageStreamListener = null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ValueListenableBuilder<FaceCameraState>(
      valueListenable: widget.controller,
      builder: (BuildContext context, FaceCameraState value, Widget? child) {
        final CameraController? cameraController = value.cameraController;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (cameraController != null &&
                cameraController.value.isInitialized) ...[
              Transform.scale(
                scale: 1.0,
                child: AspectRatio(
                  aspectRatio: size.aspectRatio,
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: SizedBox(
                        width: size.width,
                        height:
                            size.width * cameraController.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            _cameraDisplayWidget(value),
                            if (value.detectedFace != null &&
                                widget.indicatorShape !=
                                    IndicatorShape.none) ...[
                              SizedBox(
                                width: cameraController.value.previewSize!.width,
                                height:
                                    cameraController.value.previewSize!.height,
                                child: widget.indicatorBuilder?.call(
                                        context,
                                        value.detectedFace,
                                        Size(
                                          cameraController
                                              .value.previewSize!.height,
                                          cameraController
                                              .value.previewSize!.width,
                                        )) ??
                                    _buildFacePainter(
                                        value, cameraController),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ] else ...[
              const Text('No Camera Detected',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500,
                  )),
              CustomPaint(
                size: size,
                painter: HolePainter(),
              )
            ],
            if (widget.showControls) ...[
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showFlashControl) ...[
                        _flashControlWidget(value)
                      ],
                      if (widget.showCaptureControl) ...[
                        const SizedBox(width: 15),
                        _captureControlWidget(value),
                        const SizedBox(width: 15)
                      ],
                      if (widget.showCameraLensControl) ...[
                        _lensControlWidget()
                      ],
                    ],
                  ),
                ),
              )
            ]
          ],
        );
      },
    );
  }

  /// Builds a [CustomPaint] wrapping [FacePainter] with the pre-decoded
  /// indicator image injected (avoids any ImageStream work inside paint()).
  Widget _buildFacePainter(
      FaceCameraState value, CameraController cameraController) {
    final painter = FacePainter(
      face: value.detectedFace!.face,
      indicatorShape: widget.indicatorShape,
      indicatorAssetImage: widget.indicatorAssetImage,
      imageSize: Size(
        cameraController.value.previewSize!.height,
        cameraController.value.previewSize!.width,
      ),
    )..cachedIndicatorImage = _indicatorImage;
    return CustomPaint(painter: painter);
  }

  /// Renders the camera preview with an optional overlay message.
  Widget _cameraDisplayWidget(FaceCameraState value) {
    final CameraController? cameraController = value.cameraController;
    if (cameraController != null && cameraController.value.isInitialized) {
      return CameraPreview(cameraController,
          child: Builder(builder: (context) {
        if (widget.messageBuilder != null) {
          return widget.messageBuilder!.call(context, value.detectedFace);
        }
        if (widget.message != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
            child: Text(widget.message!,
                textAlign: TextAlign.center, style: widget.messageStyle),
          );
        }
        return const SizedBox.shrink();
      }));
    }
    return const SizedBox.shrink();
  }

  /// Whether the capture button should be disabled.
  bool get _disableCapture =>
      widget.autoDisableCaptureControl &&
      widget.controller.value.detectedFace?.face == null;

  /// Determines the camera controls color.
  Color? get _iconColor =>
      widget.controller.enableControls ? null : Theme.of(context).disabledColor;

  Widget _captureControlWidget(FaceCameraState value) {
    return IconButton(
      icon: widget.captureControlBuilder?.call(context, value.detectedFace) ??
          CircleAvatar(
              radius: 35,
              foregroundColor:
                  widget.controller.enableControls && !_disableCapture
                      ? null
                      : Theme.of(context).disabledColor,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.camera_alt, size: 35),
              )),
      onPressed: widget.controller.enableControls && !_disableCapture
          ? widget.controller.captureImage
          : null,
    );
  }

  Widget _flashControlWidget(FaceCameraState value) {
    final availableFlashMode = value.availableFlashMode;
    final currentFlashMode = value.currentFlashMode;
    final icon = switch (availableFlashMode[currentFlashMode]) {
      CameraFlashMode.always => Icons.flash_on,
      CameraFlashMode.off => Icons.flash_off,
      CameraFlashMode.auto => Icons.flash_auto,
    };

    return IconButton(
      icon: widget.flashControlBuilder
              ?.call(context, availableFlashMode[currentFlashMode]) ??
          CircleAvatar(
              radius: 25,
              foregroundColor: _iconColor,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(icon, size: 25),
              )),
      onPressed:
          widget.controller.enableControls ? widget.controller.changeFlashMode : null,
    );
  }

  Widget _lensControlWidget() {
    return IconButton(
        icon: widget.lensControlIcon ??
            CircleAvatar(
                radius: 25,
                foregroundColor: _iconColor,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.switch_camera_sharp, size: 25),
                )),
        onPressed: widget.controller.enableControls
            ? widget.controller.changeCameraLens
            : null);
  }
}
