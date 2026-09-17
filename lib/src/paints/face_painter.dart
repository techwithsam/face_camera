import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../face_camera.dart';


class FacePainter extends CustomPainter {
  FacePainter({
    required this.imageSize,
    this.face,
    required this.indicatorShape,
    this.indicatorAssetImage,
    this.repaint,
  }) : super(repaint: repaint);

  final Size imageSize;
  double? scaleX, scaleY;
  final Face? face;
  final IndicatorShape indicatorShape;
  final String? indicatorAssetImage;

  /// Listenable passed by [_FacePainterImageLoader] to trigger repaints when
  /// the indicator image has been decoded.
  final Listenable? repaint;

  /// Pre-decoded image for [IndicatorShape.image]. Set externally by the
  /// widget tree via [_FacePainterImageLoader] so that we never touch
  /// ImageStream inside paint().
  ui.Image? cachedIndicatorImage;

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;

    final bool headStraight =
        (face!.headEulerAngleY ?? 0).abs() <= 10;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = headStraight ? Colors.green : Colors.red;

    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    switch (indicatorShape) {
      case IndicatorShape.defaultShape:
        canvas.drawPath(
          _defaultPath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY),
          paint,
        );
        break;
      case IndicatorShape.square:
        canvas.drawRRect(
            _scaleRect(
                rect: face!.boundingBox,
                widgetSize: size,
                scaleX: scaleX,
                scaleY: scaleY),
            paint);
        break;
      case IndicatorShape.circle:
        canvas.drawCircle(
          _circleOffset(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY),
          face!.boundingBox.width / 2 * scaleX!,
          paint,
        );
        break;
      case IndicatorShape.triangle:
      case IndicatorShape.triangleInverted:
        canvas.drawPath(
          _trianglePath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              isInverted: indicatorShape == IndicatorShape.triangleInverted),
          paint,
        );
        break;
      case IndicatorShape.image:
        final img = cachedIndicatorImage;
        if (img != null) {
          final rect = face!.boundingBox;
          final destinationRect = Rect.fromPoints(
            Offset(size.width - rect.left * scaleX!, rect.top * scaleY!),
            Offset(size.width - rect.right * scaleX!, rect.bottom * scaleY!),
          );
          canvas.drawImageRect(
            img,
            Rect.fromLTRB(
                0, 0, img.width.toDouble(), img.height.toDouble()),
            destinationRect,
            Paint(),
          );
        }
        break;
      case IndicatorShape.none:
        break;
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.face != face ||
        oldDelegate.cachedIndicatorImage != cachedIndicatorImage;
  }
}

Path _defaultPath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY}) {
  double cornerExtension =
      30.0; // Adjust the length of the corner extensions as needed

  double left = widgetSize.width - rect.left.toDouble() * scaleX!;
  double right = widgetSize.width - rect.right.toDouble() * scaleX;
  double top = rect.top.toDouble() * scaleY!;
  double bottom = rect.bottom.toDouble() * scaleY;
  return Path()
    ..moveTo(left - cornerExtension, top)
    ..lineTo(left, top)
    ..lineTo(left, top + cornerExtension)
    ..moveTo(right + cornerExtension, top)
    ..lineTo(right, top)
    ..lineTo(right, top + cornerExtension)
    ..moveTo(left - cornerExtension, bottom)
    ..lineTo(left, bottom)
    ..lineTo(left, bottom - cornerExtension)
    ..moveTo(right + cornerExtension, bottom)
    ..lineTo(right, bottom)
    ..lineTo(right, bottom - cornerExtension);
}

RRect _scaleRect(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY}) {
  return RRect.fromLTRBR(
      (widgetSize.width - rect.left.toDouble() * scaleX!),
      rect.top.toDouble() * scaleY!,
      widgetSize.width - rect.right.toDouble() * scaleX,
      rect.bottom.toDouble() * scaleY,
      const Radius.circular(10));
}

Offset _circleOffset(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY}) {
  return Offset(
    (widgetSize.width - rect.center.dx * scaleX!),
    rect.center.dy * scaleY!,
  );
}

Path _trianglePath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    bool isInverted = false}) {
  if (isInverted) {
    return Path()
      ..moveTo(widgetSize.width - rect.center.dx * scaleX!,
          rect.bottom.toDouble() * scaleY!)
      ..lineTo(widgetSize.width - rect.left.toDouble() * scaleX,
          rect.top.toDouble() * scaleY)
      ..lineTo(widgetSize.width - rect.right.toDouble() * scaleX,
          rect.top.toDouble() * scaleY)
      ..close();
  }
  return Path()
    ..moveTo(widgetSize.width - rect.center.dx * scaleX!,
        rect.top.toDouble() * scaleY!)
    ..lineTo(widgetSize.width - rect.left.toDouble() * scaleX,
        rect.bottom.toDouble() * scaleY)
    ..lineTo(widgetSize.width - rect.right.toDouble() * scaleX,
        rect.bottom.toDouble() * scaleY)
    ..close();
}
