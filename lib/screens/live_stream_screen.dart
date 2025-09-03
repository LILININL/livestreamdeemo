import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_event.dart';
import 'package:livestreamdeemo/bloc/stream/stream_state.dart';
import 'package:video_player/video_player.dart';

class LiveStreamScreen extends StatefulWidget {
  final String uid;
  final String domain;

  const LiveStreamScreen({super.key, required this.uid, required this.domain});

  @override
  _LiveStreamScreenState createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  VideoPlayerController? _videoController;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoController(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: true,
        ),
        httpHeaders: {
          'Accept': 'application/vnd.apple.mpegurl',
          'User-Agent': 'Flutter/LiveStreamDemo',
        },
      );

      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timed out');
        },
      );

      setState(() {
        _errorMessage = null;
        _retryCount = 0;
        _videoController!.play();
      });

      _videoController!.addListener(() {
        if (_videoController!.value.hasError) {
          setState(() {
            _errorMessage =
                'Video error: ${_videoController!.value.errorDescription}';
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stream: $e';
      });
      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 2), () {
          context.read<StreamBloc>().add(LoadStream(widget.uid, widget.domain));
        });
      }
    }
  }

  Future<void> _retryStream() async {
    setState(() {
      _errorMessage = null;
      _retryCount = 0;
      _videoController?.dispose();
      _videoController = null;
    });
    context.read<StreamBloc>().add(LoadStream(widget.uid, widget.domain));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST_LIVESTREAM')),
      body: BlocConsumer<StreamBloc, StreamState>(
        listener: (context, state) async {
          if (state is StreamLoaded) {
            await _initializeVideoController(state.playbackUrl);
          } else if (state is StreamError) {
            setState(() {
              _errorMessage = state.message;
            });
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(seconds: 2), () {
                context.read<StreamBloc>().add(
                  LoadStream(widget.uid, widget.domain),
                );
              });
            }
          }
        },
        builder: (context, state) {
          if (state is StreamInitial) {
            context.read<StreamBloc>().add(
              LoadStream(widget.uid, widget.domain),
            );
            return const Center(child: CircularProgressIndicator());
          } else if (state is StreamLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is StreamLoaded || state is StreamError) {
            if (_errorMessage != null) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryStream,
                    child: Text(
                      'Retry Stream (Attempt ${_retryCount + 1}/$_maxRetries)',
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child:
                      _videoController != null &&
                          _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_videoController != null) {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          }
                        });
                      },
                      child: Text(
                        _videoController != null &&
                                _videoController!.value.isPlaying
                            ? 'Pause'
                            : 'Play',
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _retryStream,
                      child: const Text('Reload Stream'),
                    ),
                  ],
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
