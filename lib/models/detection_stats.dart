class DetectionStats {
  final double fps;
  final int objectCount;
  final int processingTimeMs;
  final String modelName;
  final bool trackingEnabled;

  DetectionStats({
    this.fps = 0.0,
    this.objectCount = 0,
    this.processingTimeMs = 0,
    this.modelName = 'Default ML Kit Model',
    this.trackingEnabled = false,
  });
  
  DetectionStats copyWith({
    double? fps,
    int? objectCount,
    int? processingTimeMs,
    String? modelName,
    bool? trackingEnabled,
  }) {
    return DetectionStats(
      fps: fps ?? this.fps,
      objectCount: objectCount ?? this.objectCount,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      modelName: modelName ?? this.modelName,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
    );
  }
}