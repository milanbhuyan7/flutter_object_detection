package com.example.flutter_object_detection

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.Image
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.common.model.LocalModel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.DetectedObject
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.ObjectDetector
import com.google.mlkit.vision.objects.ObjectDetectorOptionsBase
import com.google.mlkit.vision.objects.custom.CustomObjectDetectorOptions
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler {
    private val CHANNEL = "com.example.flutter_object_detection/mlkit"
    private var objectDetector: ObjectDetector? = null
    private var isDetecting = false
    private var trackingEnabled = true
    private var currentModelName = "Default ML Kit Model"
    private val availableModels = mutableListOf<Map<String, Any>>()
    
    // For tracking objects across frames
    private val trackedObjects = mutableMapOf<Int, DetectedObject>()
    private var nextTrackingId = 1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize default ML Kit Object Detector
        initializeDefaultDetector()
        
        // Initialize available models list
        initializeAvailableModels()
    }
    
    private fun initializeDefaultDetector() {
        val options = ObjectDetectorOptions.Builder()
            .setDetectorMode(ObjectDetectorOptions.STREAM_MODE)
            .enableClassification()
            .enableMultipleObjects()
            .build()
            
        objectDetector = ObjectDetection.getClient(options)
        currentModelName = "Default ML Kit Model"
    }
    
    private fun initializeCustomDetector(modelName: String) {
        try {
            // Find the model file
            val modelFile = when (modelName) {
                "Custom Object Detector" -> File(applicationContext.filesDir, "models/object_labeler.tflite")
                else -> {
                    // Try to find a model with this name in assets
                    val assetManager = applicationContext.assets
                    val modelPath = "models/$modelName.tflite"
                    
                    // Copy asset to file
                    val outputFile = File(applicationContext.filesDir, modelPath)
                    outputFile.parentFile?.mkdirs()
                    
                    assetManager.open(modelPath).use { input ->
                        outputFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    
                    outputFile
                }
            }
            
            if (!modelFile.exists()) {
                throw Exception("Model file not found: ${modelFile.absolutePath}")
            }
            
            // Create local model
            val localModel = LocalModel.Builder()
                .setAssetFilePath("models/object_labeler.tflite")
                // Or use the file path if loading from file system
                // .setAbsoluteFilePath(modelFile.absolutePath)
                .build()
                
            // Create custom detector options
            val options = CustomObjectDetectorOptions.Builder(localModel)
                .setDetectorMode(CustomObjectDetectorOptions.STREAM_MODE)
                .enableClassification()
                .enableMultipleObjects()
                .build()
                
            objectDetector = ObjectDetection.getClient(options)
            currentModelName = modelName
            
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback to default detector
            initializeDefaultDetector()
        }
    }
    
    private fun initializeAvailableModels() {
        availableModels.clear()
        
        // Add default ML Kit model
        availableModels.add(mapOf(
            "name" to "Default ML Kit Model",
            "description" to "Built-in ML Kit object detection model",
            "isCustom" to false
        ))
        
        // Add custom model
        availableModels.add(mapOf(
            "name" to "Custom Object Detector",
            "description" to "Custom TensorFlow Lite model for object detection",
            "isCustom" to true,
            "filePath" to "models/object_labeler.tflite"
        ))
        
        // Check for additional models in assets
        try {
            val assetManager = applicationContext.assets
            val modelFiles = assetManager.list("models") ?: emptyArray()
            
            for (file in modelFiles) {
                if (file.endsWith(".tflite") && file != "object_labeler.tflite") {
                    val modelName = file.removeSuffix(".tflite")
                    availableModels.add(mapOf(
                        "name" to modelName,
                        "description" to "Custom TensorFlow Lite model",
                        "isCustom" to true,
                        "filePath" to "models/$file"
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "processImage" -> {
                val imageData = call.arguments as Map<*, *>
                processImageData(imageData, result)
            }
            "stopObjectDetection" -> {
                isDetecting = false
                result.success(null)
            }
            "loadCustomModel" -> {
                val modelName = call.argument<String>("modelName") ?: "Default ML Kit Model"
                loadModel(modelName, result)
            }
            "enableObjectTracking" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                trackingEnabled = enabled
                result.success(true)
            }
            "getAvailableModels" -> {
                result.success(availableModels)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun loadModel(modelName: String, result: MethodChannel.Result) {
        try {
            if (modelName == "Default ML Kit Model") {
                initializeDefaultDetector()
            } else {
                initializeCustomDetector(modelName)
            }
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("MODEL_LOADING_ERROR", e.message, null)
        }
    }

    private fun processImageData(imageData: Map<*, *>, result: MethodChannel.Result) {
        if (isDetecting) {
            result.success(mapOf(
                "detections" to emptyList<Map<String, Any>>(),
                "processingTimeMs" to 0
            ))
            return
        }

        isDetecting = true
        val startTime = System.currentTimeMillis()

        try {
            val width = imageData["width"] as Int
            val height = imageData["height"] as Int
            val planes = imageData["planes"] as List<*>

            // Convert image data to InputImage
            val yBuffer = (planes[0] as Map<*, *>)["bytes"] as ByteArray
            val uBuffer = (planes[1] as Map<*, *>)["bytes"] as ByteArray
            val vBuffer = (planes[2] as Map<*, *>)["bytes"] as ByteArray

            val ySize = yBuffer.size
            val uSize = uBuffer.size
            val vSize = vBuffer.size

            val nv21 = ByteArray(ySize + uSize + vSize)

            System.arraycopy(yBuffer, 0, nv21, 0, ySize)
            
            // NV21 format requires interleaved UV values
            for (i in 0 until vSize) {
                nv21[ySize + i * 2] = vBuffer[i]
                nv21[ySize + i * 2 + 1] = uBuffer[i]
            }

            val yuvImage = android.graphics.YuvImage(
                nv21, android.graphics.ImageFormat.NV21, width, height, null
            )
            
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(android.graphics.Rect(0, 0, width, height), 100, out)
            val imageBytes = out.toByteArray()
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

            // Create InputImage for ML Kit
            val inputImage = InputImage.fromBitmap(bitmap, 0)

            // Process the image with ML Kit Object Detector
            objectDetector?.process(inputImage)
                ?.addOnSuccessListener { detectedObjects ->
                    val processingTime = System.currentTimeMillis() - startTime
                    
                    // Process detections with tracking if enabled
                    val detections = if (trackingEnabled) {
                        processDetectionsWithTracking(detectedObjects)
                    } else {
                        detectedObjects.map { obj ->
                            mapOf(
                                "label" to getObjectLabel(obj),
                                "confidence" to (obj.labels.firstOrNull()?.confidence ?: 0f).toDouble(),
                                "left" to obj.boundingBox.left.toDouble(),
                                "top" to obj.boundingBox.top.toDouble(),
                                "width" to obj.boundingBox.width().toDouble(),
                                "height" to obj.boundingBox.height().toDouble()
                            )
                        }
                    }
                    
                    result.success(mapOf(
                        "detections" to detections,
                        "processingTimeMs" to processingTime
                    ))
                    isDetecting = false
                }
                ?.addOnFailureListener { e ->
                    result.error("DETECTION_FAILED", e.message, null)
                    isDetecting = false
                }
        } catch (e: Exception) {
            result.error("PROCESSING_ERROR", e.message, null)
            isDetecting = false
        }
    }
    
    private fun processDetectionsWithTracking(detectedObjects: List<DetectedObject>): List<Map<String, Any>> {
        // If no previous tracked objects, assign new IDs to all
        if (trackedObjects.isEmpty()) {
            detectedObjects.forEach { obj ->
                trackedObjects[nextTrackingId] = obj
                nextTrackingId++
            }
            
            return detectedObjects.mapIndexed { index, obj ->
                mapOf(
                    "label" to getObjectLabel(obj),
                    "confidence" to (obj.labels.firstOrNull()?.confidence ?: 0f).toDouble(),
                    "left" to obj.boundingBox.left.toDouble(),
                    "top" to obj.boundingBox.top.toDouble(),
                    "width" to obj.boundingBox.width().toDouble(),
                    "height" to obj.boundingBox.height().toDouble(),
                    "trackingId" to (index + 1)
                )
            }
        }
        
        // Match current detections with tracked objects
        val matchedDetections = mutableListOf<Map<String, Any>>()
        val matchedTrackingIds = mutableSetOf<Int>()
        
        // For each detected object, find the best match in tracked objects
        for (obj in detectedObjects) {
            var bestMatchId: Int? = null
            var bestIoU = 0.5 // Minimum IoU threshold
            
            for ((trackingId, trackedObj) in trackedObjects) {
                val iou = calculateIoU(obj.boundingBox, trackedObj.boundingBox)
                if (iou > bestIoU) {
                    bestIoU = iou
                    bestMatchId = trackingId
                }
            }
            
            if (bestMatchId != null) {
                // Update tracked object
                trackedObjects[bestMatchId] = obj
                matchedTrackingIds.add(bestMatchId)
                
                matchedDetections.add(mapOf(
                    "label" to getObjectLabel(obj),
                    "confidence" to (obj.labels.firstOrNull()?.confidence ?: 0f).toDouble(),
                    "left" to obj.boundingBox.left.toDouble(),
                    "top" to obj.boundingBox.top.toDouble(),
                    "width" to obj.boundingBox.width().toDouble(),
                    "height" to obj.boundingBox.height().toDouble(),
                    "trackingId" to bestMatchId
                ))
            } else {
                // New object, assign new tracking ID
                trackedObjects[nextTrackingId] = obj
                
                matchedDetections.add(mapOf(
                    "label" to getObjectLabel(obj),
                    "confidence" to (obj.labels.firstOrNull()?.confidence ?: 0f).toDouble(),
                    "left" to obj.boundingBox.left.toDouble(),
                    "top" to obj.boundingBox.top.toDouble(),
                    "width" to obj.boundingBox.width().toDouble(),
                    "height" to obj.boundingBox.height().toDouble(),
                    "trackingId" to nextTrackingId
                ))
                
                nextTrackingId++
            }
        }
        
        // Remove tracked objects that weren't matched
        trackedObjects.keys.toList().forEach { id ->
            if (!matchedTrackingIds.contains(id)) {
                trackedObjects.remove(id)
            }
        }
        
        return matchedDetections
    }
    
    private fun calculateIoU(box1: android.graphics.Rect, box2: android.graphics.Rect): Float {
        val intersectionBox = android.graphics.Rect(box1)
        if (!intersectionBox.intersect(box2)) {
            return 0f
        }
        
        val intersectionArea = intersectionBox.width() * intersectionBox.height()
        val box1Area = box1.width() * box1.height()
        val box2Area = box2.width() * box2.height()
        val unionArea = box1Area + box2Area - intersectionArea
        
        return intersectionArea.toFloat() / unionArea.toFloat()
    }

    private fun getObjectLabel(detectedObject: DetectedObject): String {
        val label = detectedObject.labels.maxByOrNull { it.confidence }
        return label?.text ?: "Unknown"
    }
}