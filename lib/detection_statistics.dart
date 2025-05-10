import 'package:flutter/material.dart';
import 'models/detection_stats.dart';

class DetectionStatistics extends StatelessWidget {
  final DetectionStats stats;
  final bool showDetailed;

  const DetectionStatistics({
    Key? key,
    required this.stats,
    this.showDetailed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Basic statistics always shown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FPS: ${stats.fps.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Objects: ${stats.objectCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Time: ${stats.processingTimeMs}ms',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            // Detailed statistics shown only in debug mode
            if (showDetailed) ...[
              const SizedBox(height: 8),
              Text(
                'Model: ${stats.modelName}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Tracking: ${stats.trackingEnabled ? "Enabled" : "Disabled"}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}