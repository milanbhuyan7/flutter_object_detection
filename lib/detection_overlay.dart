import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detectionResults;
  final Size previewSize;
  final Size screenSize;
  final bool showTracking;

  const DetectionOverlay({
    Key? key,
    required this.detectionResults,
    required this.previewSize,
    required this.screenSize,
    this.showTracking = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DetectionPainter(
        detectionResults: detectionResults,
        previewSize: previewSize,
        screenSize: screenSize,
        showTracking: showTracking,
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<DetectionResult> detectionResults;
  final Size previewSize;
  final Size screenSize;
  final bool showTracking;
  
  // Color map for tracking IDs
  final Map<int, Color> _colorMap = {};
  final Random _random = math.Random();

  DetectionPainter({
    required this.detectionResults,
    required this.previewSize,
    required this.screenSize,
    this.showTracking = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;

    for (final detection in detectionResults) {
      // Get color for this detection
      final Color boxColor = _getDetectionColor(detection);
      
      final Paint boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final Paint textBackgroundPaint = Paint()
        ..color = boxColor.withOpacity(0.7);

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
      );

      // Scale bounding box to screen size
      final scaledRect = Rect.fromLTWH(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.width * scaleX,
        detection.boundingBox.height * scaleY,
      );

      // Draw bounding box
      canvas.drawRect(scaledRect, boxPaint);

      // Prepare label text
      String labelText = '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%';
      
      // Add tracking ID if available and tracking is enabled
      if (showTracking && detection.trackingId != null) {
        labelText += ' ID:${detection.trackingId}';
      }
      
      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw text background
      final textBackgroundRect = Rect.fromLTWH(
        scaledRect.left,
        scaledRect.top - textPainter.height,
        textPainter.width + 8,
        textPainter.height,
      );
      canvas.drawRect(textBackgroundRect, textBackgroundPaint);

      // Draw text
      textPainter.paint(
        canvas,
        Offset(scaledRect.left + 4, scaledRect.top - textPainter.height),
      );
    }
  }
  
  Color _getDetectionColor(DetectionResult detection) {
    // If tracking is disabled or no tracking ID, use red
    if (!showTracking || detection.trackingId == null) {
      return Colors.red;
    }
    
    // Get consistent color for this tracking ID
    if (!_colorMap.containsKey(detection.trackingId)) {
      // Generate a random bright color
      _colorMap[detection.trackingId!] = Color.fromARGB(
        255,
        _random.nextInt(128) + 127, // R (127-255)
        _random.nextInt(128) + 127, // G (127-255)
        _random.nextInt(128) + 127, // B (127-255)
      );
    }
    
    return _colorMap[detection.trackingId]!;
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detectionResults != detectionResults ||
           oldDelegate.showTracking != showTracking;
  }
}