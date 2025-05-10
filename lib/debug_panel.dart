import 'package:flutter/material.dart';
import 'models/detection_result.dart';
import 'models/detection_stats.dart';

class DebugPanel extends StatelessWidget {
  final DetectionStats stats;
  final List<DetectionResult> detectionResults;

  const DebugPanel({
    Key? key,
    required this.stats,
    required this.detectionResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Information',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Divider(color: Colors.white30),
          
          // Performance metrics
          _buildSection('Performance Metrics', [
            'FPS: ${stats.fps.toStringAsFixed(1)}',
            'Processing Time: ${stats.processingTimeMs}ms',
            'Average Time per Object: ${stats.objectCount > 0 ? (stats.processingTimeMs / stats.objectCount).toStringAsFixed(1) : 0}ms',
          ]),
          
          // Detection information
          _buildSection('Detection Information', [
            'Objects Detected: ${stats.objectCount}',
            'Model: ${stats.modelName}',
            'Tracking: ${stats.trackingEnabled ? "Enabled" : "Disabled"}',
          ]),
          
          // Object details
          if (detectionResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Detected Objects',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: detectionResults.length,
                itemBuilder: (context, index) {
                  final detection = detectionResults[index];
                  return Text(
                    '${index + 1}. ${detection.label} (${(detection.confidence * 100).toStringAsFixed(1)}%) ' +
                    (detection.trackingId != null ? 'ID: ${detection.trackingId}' : ''),
                    style: const TextStyle(color: Colors.white70),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Text(
          item,
          style: const TextStyle(color: Colors.white70),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}