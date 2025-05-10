import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import 'detection_overlay.dart';
import 'detection_statistics.dart';
import 'debug_panel.dart';
import 'models/detection_result.dart';
import 'models/detection_stats.dart';
import 'utils/fps_calculator.dart';

class DetectionCamera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool debugMode;
  final bool trackingEnabled;
  final String currentModel;

  const DetectionCamera({
    Key? key,
    required this.cameras,
    this.debugMode = false,
    this.trackingEnabled = true,
    required this.currentModel,
  }) : super(key: key);

  @override
  _DetectionCameraState createState() => _DetectionCameraState();
}

class _DetectionCameraState extends State<DetectionCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isDetecting = false;
  List<DetectionResult> _detectionResults = [];
  DetectionStats _stats = DetectionStats();
  String _currentModel = 'Default ML Kit Model';
  final FpsCalculator _fpsCalculator = FpsCalculator();
  
  // Platform channel for ML Kit communication
  static const MethodChannel _channel = MethodChannel('com.example.flutter_object_detection/mlkit');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentModel = widget.currentModel;
    _initializeCamera(widget.cameras.first);
  }
  
  @override
  void didUpdateWidget(DetectionCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle model changes
    if (widget.currentModel != _currentModel) {
      _currentModel = widget.currentModel;
      _loadModel();
    }
    
    // Handle tracking toggle
    if (widget.trackingEnabled != oldWidget.trackingEnabled) {
      _toggleTracking(widget.trackingEnabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(cameraController.description);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.yuv420 
          : ImageFormatGroup.bgra8888,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();
      
      // Load the selected model
      await _loadModel();
      
      // Enable tracking if needed
      await _toggleTracking(widget.trackingEnabled);
      
      // Start camera stream
      await cameraController.startImageStream(_processCameraImage);
      
      if (mounted) {
        setState(() {});
      }
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }
  
  Future<void> _loadModel() async {
    try {
      final bool success = await _channel.invokeMethod('loadCustomModel', {
        'modelName': _currentModel,
      }) ?? false;
      
      debugPrint('Model loaded: $success');
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }
  
  Future<void> _toggleTracking(bool enabled) async {
    try {
      await _channel.invokeMethod('enableObjectTracking', {
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('Error toggling tracking: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isDetecting) {
      _isDetecting = true;
      final Stopwatch stopwatch = Stopwatch()..start();
      
      try {
        // Prepare image data for platform channel
        final Map<String, dynamic> imageData = {
          'width': image.width,
          'height': image.height,
          'format': image.format.raw,
          'planes': image.planes.map((plane) => {
            'bytes': plane.bytes,
            'bytesPerRow': plane.bytesPerRow,
            'bytesPerPixel': plane.bytesPerPixel,
          }).toList(),
        };
        
        // Send image to native code for processing
        final Map<String, dynamic>? result = await _channel.invokeMethod('processImage', imageData);
        
        if (result != null) {
          final List<dynamic> detections = result['detections'] ?? [];
          final int processingTimeMs = result['processingTimeMs'] ?? 0;
          
          // Update FPS
          _fpsCalculator.addFrame();
          
          setState(() {
            _detectionResults = detections.map((detection) => 
              DetectionResult.fromMap(Map<String, dynamic>.from(detection))
            ).toList();
            
            // Update statistics
            _stats = DetectionStats(
              fps: _fpsCalculator.fps,
              objectCount: _detectionResults.length,
              processingTimeMs: processingTimeMs,
              modelName: _currentModel,
              trackingEnabled: widget.trackingEnabled,
            );
          });
        }
      } catch (e) {
        debugPrint('Error processing image: $e');
      }
      
      stopwatch.stop();
      _isDetecting = false;
    }
  }

  Future<void> _stopDetection() async {
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      await _channel.invokeMethod('stopObjectDetection');
    } catch (e) {
      debugPrint('Error stopping detection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(_controller!),
        
        // Detection overlay
        DetectionOverlay(
          detectionResults: _detectionResults,
          previewSize: _controller!.value.previewSize!,
          screenSize: MediaQuery.of(context).size,
          showTracking: widget.trackingEnabled,
        ),
        
        // Statistics overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DetectionStatistics(
            stats: _stats,
            showDetailed: widget.debugMode,
          ),
        ),
        
        // Debug panel (only shown in debug mode)
        if (widget.debugMode)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DebugPanel(
              stats: _stats,
              detectionResults: _detectionResults,
            ),
          ),
      ],
    );
  }
}