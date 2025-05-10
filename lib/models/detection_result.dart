import 'dart:ui';

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final int? trackingId;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.trackingId,
  });

  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    return DetectionResult(
      label: map['label'] as String,
      confidence: map['confidence'] as double,
      boundingBox: Rect.fromLTWH(
        map['left'] as double,
        map['top'] as double,
        map['width'] as double,
        map['height'] as double,
      ),
      trackingId: map['trackingId'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'left': boundingBox.left,
      'top': boundingBox.top,
      'width': boundingBox.width,
      'height': boundingBox.height,
      'trackingId': trackingId,
    };
  }
  
  DetectionResult copyWith({
    String? label,
    double? confidence,
    Rect? boundingBox,
    int? trackingId,
  }) {
    return DetectionResult(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      trackingId: trackingId ?? this.trackingId,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(label: $label, confidence: $confidence, boundingBox: $boundingBox, trackingId: $trackingId)';
  }
}