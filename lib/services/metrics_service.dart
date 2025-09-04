import 'package:video_player/video_player.dart';
import 'dart:async';

class MetricsService {
  static double calculateLatency() {
    // Simulate network latency calculation
    return 30.0 + (DateTime.now().millisecondsSinceEpoch % 100);
  }

  static String getNetworkSpeed(double latency) {
    if (latency < 50) {
      return 'Excellent';
    } else if (latency < 100) {
      return 'Good';
    } else if (latency < 200) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  static Map<String, dynamic> updateVideoMetrics(
    VideoPlayerController? controller, 
    String currentQuality,
    double latency
  ) {
    if (controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      return {
        'resolution': '${size.width.toInt()}x${size.height.toInt()}',
        'frameRate': 30.0,
        'bitrate': currentQuality == 'Auto' ? 'Adaptive' : '2.5 Mbps',
        'networkSpeed': getNetworkSpeed(latency),
      };
    }
    return {
      'resolution': 'Unknown',
      'frameRate': 0.0,
      'bitrate': 'Unknown',
      'networkSpeed': 'Unknown',
    };
  }

  static double calculateBufferHealth(VideoPlayerController? controller) {
    if (controller != null && controller.value.isInitialized) {
      final buffered = controller.value.buffered;
      final position = controller.value.position;

      if (buffered.isNotEmpty) {
        final bufferEnd = buffered.last.end;
        final bufferAhead = bufferEnd - position;
        return bufferAhead.inMilliseconds / 1000.0;
      }
    }
    return 0.0;
  }

  static bool isBuffering(VideoPlayerController? controller) {
    return controller != null &&
        !controller.value.isPlaying &&
        controller.value.isInitialized &&
        !controller.value.hasError;
  }
}
