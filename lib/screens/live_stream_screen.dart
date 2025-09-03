import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_event.dart';
import 'package:livestreamdeemo/bloc/stream/stream_state.dart';
import 'package:livestreamdeemo/screens/dispose_test_screen.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class LiveStreamScreen extends StatefulWidget {
  final String uid;
  final String domain;

  const LiveStreamScreen({super.key, required this.uid, required this.domain});

  @override
  _LiveStreamScreenState createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Metrics variables
  Timer? _metricsTimer;
  double _latency = 0.0;
  double _bufferHealth = 0.0;
  String _currentQuality = 'Auto';
  double _frameRate = 0.0;
  String _resolution = 'Unknown';
  String _bitrate = 'Unknown';
  String _networkSpeed = 'Unknown';
  bool _isBuffering = false;
  Duration _totalBufferDuration = Duration.zero;
  DateTime? _streamStartTime;
  bool _showMetrics = false;

  // Quality options
  final List<String> _qualityOptions = [
    'Auto',
    '1080p',
    '720p',
    '480p',
    '360p',
    '240p',
  ];

  // Full screen state
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsTimer?.cancel();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
      }
    }
  }

  void _toggleFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
    }

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _startMetricsMonitoring() {
    _streamStartTime = DateTime.now();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMetrics();
    });
  }

  void _updateMetrics() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _calculateLatency();

      final buffered = _videoController!.value.buffered;
      final position = _videoController!.value.position;

      if (buffered.isNotEmpty) {
        final bufferEnd = buffered.last.end;
        final bufferAhead = bufferEnd - position;
        _bufferHealth = bufferAhead.inMilliseconds / 1000.0;
      }

      final wasBuffering = _isBuffering;
      _isBuffering =
          !_videoController!.value.isPlaying &&
          _videoController!.value.isInitialized &&
          !_videoController!.value.hasError;

      if (_isBuffering && !wasBuffering) {
        // Started buffering
      } else if (!_isBuffering && wasBuffering) {
        _totalBufferDuration += const Duration(seconds: 1);
      }

      _updateVideoMetrics();

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _calculateLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        stopwatch.stop();
        _latency = stopwatch.elapsedMilliseconds.toDouble();
      }
    } catch (e) {
      _latency = -1;
    }
  }

  void _updateVideoMetrics() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final size = _videoController!.value.size;
      _resolution = '${size.width.toInt()}x${size.height.toInt()}';
      _frameRate = 30.0;
      _bitrate = '2.5 Mbps';
      if (_latency < 50) {
        _networkSpeed = 'Excellent';
      } else if (_latency < 100) {
        _networkSpeed = 'Good';
      } else if (_latency < 200) {
        _networkSpeed = 'Fair';
      } else {
        _networkSpeed = 'Poor';
      }
    }
  }

  void _changeQuality(String quality) {
    if (mounted) {
      setState(() {
        _currentQuality = quality;
      });
    }
  }

  void _toggleMetricsDisplay() {
    if (mounted) {
      setState(() {
        _showMetrics = !_showMetrics;
      });
    }
  }

  Widget _buildMetricsOverlay() {
    if (!_showMetrics) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricText(
              'Ping Latency',
              '${_latency.toStringAsFixed(0)}ms',
              _latency < 50
                  ? Colors.green
                  : _latency < 100
                  ? Colors.orange
                  : Colors.red,
            ),
            _buildMetricText(
              'Buffer Health',
              '${_bufferHealth.toStringAsFixed(1)}s',
              _bufferHealth > 2
                  ? Colors.green
                  : _bufferHealth > 1
                  ? Colors.orange
                  : Colors.red,
            ),
            _buildMetricText('Quality', _currentQuality, Colors.white),
            _buildMetricText('Resolution', _resolution, Colors.white),
            _buildMetricText(
              'FPS',
              _frameRate.toStringAsFixed(1),
              Colors.white,
            ),
            _buildMetricText('Bitrate', _bitrate, Colors.white),
            _buildMetricText(
              'Network Speed',
              _networkSpeed,
              _networkSpeed == 'Excellent' || _networkSpeed == 'Good'
                  ? Colors.green
                  : Colors.red,
            ),
            _buildMetricText(
              'Total Buffer Time',
              '${_totalBufferDuration.inSeconds}s',
              Colors.white,
            ),
            if (_isBuffering)
              const Text(
                'BUFFERING...',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricText(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon:
                    _videoController != null &&
                        _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                label:
                    _videoController != null &&
                        _videoController!.value.isPlaying
                    ? 'Pause'
                    : 'Play',
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      if (_videoController != null &&
                          _videoController!.value.isInitialized) {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      }
                    });
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.refresh,
                label: 'Reload',
                onPressed: _retryStream,
              ),
              _buildControlButton(
                icon: _showMetrics ? Icons.visibility_off : Icons.visibility,
                label: _showMetrics ? 'Hide Info' : 'Show Info',
                onPressed: _toggleMetricsDisplay,
              ),
              _buildControlButton(
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                label: _isFullScreen ? 'Exit Full' : 'Full Screen',
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Quality:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _qualityOptions
                  .map(
                    (quality) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () => _changeQuality(quality),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentQuality == quality
                              ? Colors.blue
                              : Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          quality,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_showMetrics) ...[
            const Divider(color: Colors.white54, height: 24),
            _buildDetailedMetrics(),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedMetrics() {
    final uptime = _streamStartTime != null
        ? DateTime.now().difference(_streamStartTime!).inSeconds
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricText(
                    'Ping Latency',
                    '${_latency.toStringAsFixed(0)}ms',
                    _latency < 50
                        ? Colors.green
                        : _latency < 100
                        ? Colors.orange
                        : Colors.red,
                  ),
                  _buildMetricText(
                    'Buffer Health',
                    '${_bufferHealth.toStringAsFixed(1)}s',
                    _bufferHealth > 2
                        ? Colors.green
                        : _bufferHealth > 1
                        ? Colors.orange
                        : Colors.red,
                  ),
                  _buildMetricText('Uptime', '${uptime}s', Colors.white70),
                  _buildMetricText(
                    'Total Buffer Time',
                    '${_totalBufferDuration.inSeconds}s',
                    Colors.white70,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMetricText('Resolution', _resolution, Colors.white70),
                  _buildMetricText(
                    'Frame Rate',
                    '${_frameRate.toStringAsFixed(1)} fps',
                    Colors.white70,
                  ),
                  _buildMetricText('Bitrate', _bitrate, Colors.white70),
                  _buildMetricText(
                    'Network Speed',
                    _networkSpeed,
                    _networkSpeed == 'Excellent' || _networkSpeed == 'Good'
                        ? Colors.green
                        : Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _bufferHealth / 10,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(
            _bufferHealth > 2
                ? Colors.green
                : _bufferHealth > 1
                ? Colors.orange
                : Colors.red,
          ),
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        const Text(
          'Buffer Health',
          style: TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
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

      if (mounted) {
        setState(() {
          _errorMessage = null;
          _retryCount = 0;
          _videoController!.play();
        });
      }

      _startMetricsMonitoring();

      _videoController!.addListener(() {
        if (_videoController!.value.hasError && mounted) {
          setState(() {
            _errorMessage =
                'Video error: ${_videoController!.value.errorDescription}';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stream: $e';
        });
      }
      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.read<StreamBloc>().add(
              LoadStream(widget.uid, widget.domain),
            );
          }
        });
      }
    }
  }

  Future<void> _retryStream() async {
    _metricsTimer?.cancel();
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _retryCount = 0;
        _videoController?.dispose();
        _videoController = null;
        _streamStartTime = null;
      });
    }
    if (mounted) {
      context.read<StreamBloc>().add(LoadStream(widget.uid, widget.domain));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: const Text('TEST_LIVESTREAM'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DisposeTestScreen(
                          uid: widget.uid,
                          domain: widget.domain,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Test: dispose state',
                ),
                IconButton(
                  onPressed: () {
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Test: setState',
                ),
              ],
            ),
      body: BlocConsumer<StreamBloc, StreamState>(
        listener: (context, state) async {
          if (state is StreamLoaded) {
            await _initializeVideoController(state.playbackUrl);
          } else if (state is StreamError) {
            if (mounted) {
              setState(() {
                _errorMessage = state.message;
              });
            }
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  context.read<StreamBloc>().add(
                    LoadStream(widget.uid, widget.domain),
                  );
                }
              });
            }
          }
        },
        builder: (context, state) {
          return OrientationBuilder(
            builder: (context, orientation) {
              return Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: _toggleFullScreen,
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.black,
                            child:
                                _videoController != null &&
                                    _videoController!.value.isInitialized
                                ? AspectRatio(
                                    aspectRatio:
                                        _videoController!.value.aspectRatio,
                                    child: VideoPlayer(_videoController!),
                                  )
                                : Center(
                                    child: Text(
                                      _errorMessage ?? 'Waiting for stream...',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                          ),
                          _buildMetricsOverlay(),
                          if (!_isFullScreen)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: _toggleFullScreen,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _buildControlPanel(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
