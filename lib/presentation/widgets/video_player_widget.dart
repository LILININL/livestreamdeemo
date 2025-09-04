import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoPlayerController? controller;

  const VideoPlayerWidget({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    debugPrint('=== VideoPlayerWidget: build() ===');
    debugPrint('VideoPlayerWidget: Controller is null: ${controller == null}');

    if (controller != null) {
      debugPrint(
        'VideoPlayerWidget: Controller initialized: ${controller!.value.isInitialized}',
      );
      debugPrint(
        'VideoPlayerWidget: Controller playing: ${controller!.value.isPlaying}',
      );
      debugPrint(
        'VideoPlayerWidget: Controller has error: ${controller!.value.hasError}',
      );
      if (controller!.value.hasError) {
        debugPrint(
          'VideoPlayerWidget: Error description: ${controller!.value.errorDescription}',
        );
      }
    }

    return controller?.value.isInitialized ?? false
        ? AspectRatio(
            aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
            child: VideoPlayer(controller!),
          )
        : Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
  }
}
