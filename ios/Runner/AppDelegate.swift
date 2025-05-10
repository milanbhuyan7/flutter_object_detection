import UIKit
import Flutter
import MLKit
import MLImage

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "com.example.flutter_object_detection/mlkit"
    private var objectDetector: ObjectDetector?
    private var isDetecting = false
    private var trackingEnabled = true
    private var currentModelName = "Default ML Kit Model"
    private var availableModels: [[String: Any]] = []
    
    // For tracking objects across frames
    private var trackedObjects: [Int: VisionObject] = [:]
    private var nextTrackingId = 1
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            
            switch call.method {
            case "processImage":
                if let args = call.arguments as? [String: Any] {
                    self.processImage(args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                      message: "Invalid arguments",
                                      details: nil))
                }
            case "stopObjectDetection":
                self.isDetecting = false
                result(nil)
            case "loadCustomModel":
                if let args = call.arguments as? [String: Any],
                   let modelName = args["modelName"] as? String {
                    self.loadModel(modelName: modelName, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS",
                                      message: "Invalid model name",
                                      details: nil))
                }
            case "enableObjectTracking":
                if let args = call.arguments as? [String: Any],
                   let enabled = args["enabled"] as? Bool {
                    self.trackingEnabled = enabled
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid tracking flag", details: nil))
                }
            case "getAvailableModels":
                result(self.availableModels)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func initializeDefaultDetector() {
        let options = ObjectDetectorOptions()
        options.detectorMode = .stream
        options.shouldEnableClassification = true
        options.shouldEnableMultipleObjects = true
        objectDetector = ObjectDetector.objectDetector(options: options)
        currentModelName = "Default ML Kit Model"
    }
    
    private func initializeCustomDetector(modelName: String) throws {
        // Find the model file
        var modelPath: String
        
        if modelName == "Custom Object Detector" {
            modelPath = "models/object_labeler.tflite"
        } else {
            // Try to find a model with this name in the bundle
            modelPath = "models/\(modelName).tflite"
        }
        
        guard let modelURL = Bundle.main.url(forResource: modelPath, withExtension: nil) else {
            throw NSError(domain: "ObjectDetection", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model file not found: \(modelPath)"])
        }
        
        // Create local model
        let localModel = LocalModel(path: modelURL.path)
        
        // Create custom detector options
        let options = CustomObjectDetectorOptions(localModel: localModel)
        options.detectorMode = .stream
        options.shouldEnableClassification = true
        options.shouldEnableMultipleObjects = true
        
        objectDetector = ObjectDetector.objectDetector(options: options)
        currentModelName = modelName
    }
    
    private func initializeAvailableModels() {
        availableModels.removeAll()
        
        // Add default ML Kit model
        availableModels.append([
            "name": "Default ML Kit Model",
            "description": "Built-in ML Kit object detection model",
            "isCustom": false
        ])
        
        // Add custom model
        availableModels.append([
            "name": "Custom Object Detector",
            "description": "Custom TensorFlow Lite model for object detection",
            "isCustom": true,
            "filePath": "models/object_labeler.tflite"
        ])
        
        // Check for additional models in the bundle
        if let modelURLs = Bundle.main.urls(forResourcesWithExtension: "tflite", subdirectory: "models") {
            for url in modelURLs {
                let filename = url.lastPathComponent
                if filename != "object_labeler.tflite" {
                    let modelName = filename.replacingOccurrences(of: ".tflite", with: "")
                    availableModels.append([
                        "name": modelName,
                        "description": "Custom TensorFlow Lite model",
                        "isCustom": true,
                        "filePath": "models/\(filename)"
                    ])
                }
            }
        }
    }
    
    private func loadModel(modelName: String, result: @escaping FlutterResult) {
        do {
            if modelName == "Default ML Kit Model" {
                initializeDefaultDetector()
                result(true)
            } else {
                try initializeCustomDetector(modelName: modelName)
                result(true)
            }
        } catch {
            result(FlutterError(code: "MODEL_LOADING_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }
    
    private func processImage(_ imageData: [String: Any], result: @escaping FlutterResult) {
        if isDetecting {
            result(["detections": [], "processingTimeMs": 0])
            return
        }
        
        isDetecting = true
        let startTime = Date()
        
        guard let image = imageData["image"] as? FlutterStandardTypedData,
              let uiImage = UIImage(data: image.data) else {
            result(FlutterError(code: "INVALID_IMAGE",
                              message: "Invalid image data",
                              details: nil))
            return
        }
        
        let visionImage = VisionImage(image: uiImage)
        
        objectDetector?.process(visionImage) { [weak self] detectedObjects, error in
            guard let self = self else { return }
            self.isDetecting = false
            
            if let error = error {
                result(FlutterError(code: "DETECTION_ERROR",
                                  message: error.localizedDescription,
                                  details: nil))
                return
            }
            
            let processingTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let detections = detectedObjects?.map { object -> [String: Any] in
                var detection: [String: Any] = [
                    "boundingBox": [
                        "left": object.frame.origin.x,
                        "top": object.frame.origin.y,
                        "width": object.frame.width,
                        "height": object.frame.height
                    ]
                ]
                
                if let trackingID = object.trackingID {
                    detection["trackingId"] = trackingID
                }
                
                if let labels = object.labels {
                    detection["labels"] = labels.map { label -> [String: Any] in
                        return [
                            "text": label.text,
                            "confidence": label.confidence
                        ]
                    }
                }
                
                return detection
            } ?? []
            
            result([
                "detections": detections,
                "processingTimeMs": processingTimeMs
            ])
        }
    }
    
    private func processDetectionsWithTracking(_ detectedObjects: [VisionObject]) -> [[String: Any]] {
        // If no previous tracked objects, assign new IDs to all
        if trackedObjects.isEmpty {
            for (index, obj) in detectedObjects.enumerated() {
                let trackingId = index + 1
                trackedObjects[trackingId] = obj
                nextTrackingId = trackingId + 1
            }
            
            return detectedObjects.enumerated().map { index, object in
                let frame = object.frame
                var label = "Unknown"
                var confidence: Float = 0.0
                
                if let firstLabel = object.labels.first {
                    label = firstLabel.text
                    confidence = firstLabel.confidence
                }
                
                return [
                    "label": label,
                    "confidence": Double(confidence),
                    "left": Double(frame.origin.x),
                    "top": Double(frame.origin.y),
                    "width": Double(frame.size.width),
                    "height": Double(frame.size.height),
                    "trackingId": index + 1
                ]
            }
        }
        
        // Match current detections with tracked objects
        var matchedDetections: [[String: Any]] = []
        var matchedTrackingIds: Set<Int> = []
        
        // For each detected object, find the best match in tracked objects
        for object in detectedObjects {
            var bestMatchId: Int? = nil
            var bestIoU: Float = 0.5 // Minimum IoU threshold
            
            for (trackingId, trackedObj) in trackedObjects {
                let iou = calculateIoU(object.frame, trackedObj.frame)
                if iou > bestIoU {
                    bestIoU = iou
                    bestMatchId = trackingId
                }
            }
            
            var label = "Unknown"
            var confidence: Float = 0.0
            
            if let firstLabel = object.labels.first {
                label = firstLabel.text
                confidence = firstLabel.confidence
            }
            
            let frame = object.frame
            
            if let trackingId = bestMatchId {
                // Update tracked object
                trackedObjects[trackingId] = object
                matchedTrackingIds.insert(trackingId)
                
                matchedDetections.append([
                    "label": label,
                    "confidence": Double(confidence),
                    "left": Double(frame.origin.x),
                    "top": Double(frame.origin.y),
                    "width": Double(frame.size.width),
                    "height": Double(frame.size.height),
                    "trackingId": trackingId
                ])
            } else {
                // New object, assign new tracking ID
                trackedObjects[nextTrackingId] = object
                
                matchedDetections.append([
                    "label": label,
                    "confidence": Double(confidence),
                    "left": Double(frame.origin.x),
                    "top": Double(frame.origin.y),
                    "width": Double(frame.size.width),
                    "height": Double(frame.size.height),
                    "trackingId": nextTrackingId
                ])
                
                nextTrackingId += 1
            }
        }
        
        // Remove tracked objects that weren't matched
        for trackingId in trackedObjects.keys {
            if !matchedTrackingIds.contains(trackingId) {
                trackedObjects.removeValue(forKey: trackingId)
            }
        }
        
        return matchedDetections
    }
    
    private func calculateIoU(_ rect1: CGRect, _ rect2: CGRect) -> Float {
        let intersectionRect = rect1.intersection(rect2)
        
        if intersectionRect.isEmpty {
            return 0.0
        }
        
        let intersectionArea = intersectionRect.width * intersectionRect.height
        let rect1Area = rect1.width * rect1.height
        let rect2Area = rect2.width * rect2.height
        let unionArea = rect1Area + rect2Area - intersectionArea
        
        return Float(intersectionArea / unionArea)
    }
    
    private func imageFromBuffer(_ buffer: Data, width: Int, height: Int) -> UIImage? {
        // Convert BGRA buffer to UIImage
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let provider = CGDataProvider(data: buffer as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func imageOrientation() -> UIImage.Orientation {
        // Get the device orientation to properly rotate the image
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
            return .up
        }
        
        switch orientation {
        case .portrait:
            return .right
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        case .portraitUpsideDown:
            return .left
        default:
            return .up
        }
    }
}