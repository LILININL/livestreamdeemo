import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_event.dart';

class VideoService {
  Future<VideoPlayerController?> initializeVideoController(
    String url,
    Function(String?) onError,
    Function(VideoPlayerController) onSuccess,
  ) async {
    debugPrint('=== VideoService: initializeVideoController START ===');
    debugPrint('VideoService: Received URL: $url');
    debugPrint('VideoService: URL Length: ${url.length} characters');
    debugPrint('VideoService: URL Type: ${Uri.tryParse(url)?.scheme ?? 'Invalid URL'}');
    
    try {
      debugPrint('VideoService: Creating VideoPlayerController with NetworkUrl');
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: true,
        ),
      );

      debugPrint('VideoService: Starting video controller initialization...');
      debugPrint('VideoService: Timeout set to 10 seconds');
      
      await videoController.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('VideoService: ❌ Video initialization TIMED OUT after 10 seconds');
          throw Exception('Video initialization timed out');
        },
      );

      debugPrint('VideoService: ✅ Video controller initialized successfully!');
      debugPrint('VideoService: Video duration: ${videoController.value.duration}');
      debugPrint('VideoService: Video size: ${videoController.value.size}');
      debugPrint('VideoService: Video aspect ratio: ${videoController.value.aspectRatio}');
      debugPrint('VideoService: Has video: ${videoController.value.size != Size.zero}');

      videoController.addListener(() {
        if (videoController.value.hasError) {
          debugPrint('VideoService: ❌ Video controller error: ${videoController.value.errorDescription}');
          onError('Video error: ${videoController.value.errorDescription}');
        }
      });

      debugPrint('VideoService: Calling onSuccess callback');
      onSuccess(videoController);
      debugPrint('=== VideoService: initializeVideoController SUCCESS ===');
      return videoController;
    } catch (e) {
      debugPrint('=== VideoService: initializeVideoController ERROR ===');
      debugPrint('VideoService: ❌ Error occurred: $e');
      debugPrint('VideoService: Error type: ${e.runtimeType}');
      onError('Failed to load stream: $e');
      return null;
    }
  }

  Future<void> changeQuality(
    String quality,
    String? basePlaybackUrl,
    VideoPlayerController? currentController,
    Function(VideoPlayerController) onSuccess,
    Function(String?) onError,
  ) async {
    if (basePlaybackUrl != null) {
      await currentController?.pause();
      await currentController?.dispose();

      String newUrl = basePlaybackUrl;
      if (quality != 'Auto') {
        newUrl = Uri.parse(basePlaybackUrl)
            .replace(queryParameters: {'quality': quality.toLowerCase()})
            .toString();
      }

      await initializeVideoController(newUrl, onError, onSuccess);
    }
  }

  void retryStream(
    int retryCount,
    int maxRetries,
    Function onRetry,
    Function onMaxRetriesReached,
    StreamBloc streamBloc,
    String uid,
    String domain,
  ) {
    if (retryCount < maxRetries) {
      onRetry();
      Future.delayed(const Duration(seconds: 2), () {
        streamBloc.add(LoadStream(uid, domain));
      });
    } else {
      onMaxRetriesReached();
    }
  }
}
