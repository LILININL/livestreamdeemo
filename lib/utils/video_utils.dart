import 'dart:async';
import 'dart:io';

Future<double> calculateLatency() async {
  try {
    final stopwatch = Stopwatch()..start();
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.toDouble();
    }
  } catch (e) {
    return -1;
  }
  return -1;
}

String formatTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
