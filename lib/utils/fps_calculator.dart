class FpsCalculator {
  final List<DateTime> _frames = [];
  final int _maxFrameHistory = 30;
  
  double _fps = 0.0;
  
  double get fps => _fps;
  
  void addFrame() {
    final now = DateTime.now();
    
    // Add current frame timestamp
    _frames.add(now);
    
    // Remove old frames
    while (_frames.length > _maxFrameHistory) {
      _frames.removeAt(0);
    }
    
    // Calculate FPS if we have enough frames
    if (_frames.length >= 2) {
      final Duration duration = _frames.last.difference(_frames.first);
      final double seconds = duration.inMilliseconds / 1000.0;
      
      if (seconds > 0) {
        _fps = (_frames.length - 1) / seconds;
      }
    }
  }
  
  void reset() {
    _frames.clear();
    _fps = 0.0;
  }
}