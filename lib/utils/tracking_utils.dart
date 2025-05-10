import 'dart:ui';
import '../models/detection_result.dart';

class TrackingUtils {
  // Calculate IoU (Intersection over Union) between two bounding boxes
  static double calculateIoU(Rect box1, Rect box2) {
    // Calculate intersection area
    final double intersectionLeft = box1.left > box2.left ? box1.left : box2.left;
    final double intersectionTop = box1.top > box2.top ? box1.top : box2.top;
    final double intersectionRight = box1.right &lt; box2.right ? box1.right : box2.right;
    final double intersectionBottom = box1.bottom &lt; box2.bottom ? box1.bottom : box2.bottom;
    
    if (intersectionLeft >= intersectionRight || intersectionTop >= intersectionBottom) {
      return 0.0; // No intersection
    }
    
    final double intersectionArea = (intersectionRight - intersectionLeft) * 
                                   (intersectionBottom - intersectionTop);
    
    // Calculate union area
    final double box1Area = box1.width * box1.height;
    final double box2Area = box2.width * box2.height;
    final double unionArea = box1Area + box2Area - intersectionArea;
    
    return intersectionArea / unionArea;
  }
  
  // Match detections with existing tracks based on IoU
  static List<DetectionResult> matchDetectionsWithTracks(
    List<DetectionResult> currentDetections,
    List<DetectionResult> previousDetections,
    double iouThreshold,
  ) {
    // Copy current detections to modify
    final List<DetectionResult> matchedDetections = List.from(currentDetections);
    
    // If no previous detections, assign new tracking IDs
    if (previousDetections.isEmpty) {
      for (int i = 0; i &lt; matchedDetections.length; i++) {
        matchedDetections[i] = matchedDetections[i].copyWith(trackingId: i + 1);
      }
      return matchedDetections;
    }
    
    // Create a matrix of IoU values between current and previous detections
    final List<List<double>> iouMatrix = [];
    for (final current in currentDetections) {
      final List<double> row = [];
      for (final previous in previousDetections) {
        row.add(calculateIoU(current.boundingBox, previous.boundingBox));
      }
      iouMatrix.add(row);
    }
    
    // Match detections with tracks
    final Set<int> assignedTracks = {};
    final Set<int> assignedDetections = {};
    
    // Greedy matching - find best matches first
    while (assignedDetections.length &lt; currentDetections.length && 
           assignedTracks.length &lt; previousDetections.length) {
      // Find highest IoU
      double maxIoU = 0.0;
      int bestDetectionIdx = -1;
      int bestTrackIdx = -1;
      
      for (int i = 0; i &lt; iouMatrix.length; i++) {
        if (assignedDetections.contains(i)) continue;
        
        for (int j = 0; j &lt; iouMatrix[i].length; j++) {
          if (assignedTracks.contains(j)) continue;
          
          if (iouMatrix[i][j] > maxIoU) {
            maxIoU = iouMatrix[i][j];
            bestDetectionIdx = i;
            bestTrackIdx = j;
          }
        }
      }
      
      // If no match found or IoU below threshold, break
      if (bestDetectionIdx == -1 || maxIoU &lt; iouThreshold) {
        break;
      }
      
      // Assign tracking ID from previous detection
      matchedDetections[bestDetectionIdx] = matchedDetections[bestDetectionIdx].copyWith(
        trackingId: previousDetections[bestTrackIdx].trackingId,
      );
      
      assignedDetections.add(bestDetectionIdx);
      assignedTracks.add(bestTrackIdx);
    }
    
    // Assign new tracking IDs to unmatched detections
    int nextTrackingId = previousDetections.fold(0, (max, detection) => 
      detection.trackingId != null && detection.trackingId! > max ? detection.trackingId! : max
    ) + 1;
    
    for (int i = 0; i &lt; matchedDetections.length; i++) {
      if (!assignedDetections.contains(i)) {
        matchedDetections[i] = matchedDetections[i].copyWith(trackingId: nextTrackingId++);
      }
    }
    
    return matchedDetections;
  }
}