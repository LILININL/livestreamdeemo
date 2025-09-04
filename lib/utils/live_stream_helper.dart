import 'package:video_player/video_player.dart';
import 'dart:async';

class LiveStreamHelper {
  final VideoPlayerController? videoController;
  final Function(Duration) onBufferUpdate;
  final Function(double) onLatencyUpdate;

  LiveStreamHelper({
    required this.videoController,
    required this.onBufferUpdate,
    required this.onLatencyUpdate,
  });

  Future<void> calculateLatency() async {
    double latency = await Future.delayed(
      const Duration(milliseconds: 50),
      () => 30.0,
    );
    onLatencyUpdate(latency);
  }

  void updateMetrics() {
    if (videoController != null && videoController!.value.isInitialized) {
      final buffered = videoController!.value.buffered;
      final position = videoController!.value.position;

      if (buffered.isNotEmpty) {
        final bufferEnd = buffered.last.end;
        final bufferAhead = bufferEnd - position;
        onBufferUpdate(bufferAhead);
      }
    }
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }
}
