import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_event.dart';
import 'package:livestreamdeemo/bloc/stream/stream_state.dart';
import 'package:livestreamdeemo/screens/dispose_test_screen.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'package:livestreamdeemo/utils/live_stream_helper.dart';
import 'package:livestreamdeemo/services/video_service.dart';
import 'package:livestreamdeemo/services/metrics_service.dart';
import 'package:livestreamdeemo/services/screen_service.dart';
import 'package:floating/floating.dart';

class LiveStreamScreen extends StatefulWidget {
  final String uid;
  final String domain;

  const LiveStreamScreen({super.key, required this.uid, required this.domain});

  @override
  _LiveStreamScreenState createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _basePlaybackUrl;

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

  // Full screen and control panel state
  bool _isFullScreen = false;
  bool _showControlPanel = false;
  bool _isPiPMode = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Connection status
  String _connectionStatus = 'Connecting...';
  Color _connectionStatusColor = Colors.orange;

  late LiveStreamHelper _liveStreamHelper;
  final VideoService _videoService = VideoService();

  // Floating package for PiP
  final Floating _floating = Floating();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenService.setAllOrientations();

    // Hide system UI (navigation bar and status bar) for immersive experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all overlays including navigation bar
    );
    // Initialize animation controller for control panel slide
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    // Autoplay the video when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        'LiveStreamScreen: initState - Adding LoadStream event with uid: ${widget.uid}, domain: ${widget.domain}',
      );
      context.read<StreamBloc>().add(LoadStream(widget.uid, widget.domain));
    });

    _liveStreamHelper = LiveStreamHelper(
      videoController: _videoController,
      onBufferUpdate: (bufferAhead) {
        if (mounted) {
          setState(() {
            _bufferHealth = bufferAhead.inMilliseconds / 1000.0;
          });
        }
      },
      onLatencyUpdate: (latency) {
        if (mounted) {
          setState(() {
            _latency = latency;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsTimer?.cancel();
    _videoController?.dispose();
    _animationController.dispose();
    ScreenService.setPortraitOnly();

    // Restore system UI when leaving the screen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values, // Show all overlays back
    );

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // When app resumes, exit PiP mode
      if (_isPiPMode && mounted) {
        setState(() {
          _isPiPMode = false;
        });
      }
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
      }
    }
  }

  void _startMetricsMonitoring() {
    debugPrint('LiveStreamScreen: Starting metrics monitoring');
    _streamStartTime = DateTime.now();

    // Increase timer to 5 seconds to reduce performance issues significantly
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      debugPrint(
        'LiveStreamScreen: Metrics timer tick - mounted: $mounted, controller: ${_videoController != null}',
      );

      if (mounted && _videoController != null) {
        setState(() {
          _latency = MetricsService.calculateLatency();
          _bufferHealth = MetricsService.calculateBufferHealth(
            _videoController,
          );
          _isBuffering = MetricsService.isBuffering(_videoController);

          final metrics = MetricsService.updateVideoMetrics(
            _videoController,
            _currentQuality,
            _latency,
          );
          _resolution = metrics['resolution'];
          _frameRate = metrics['frameRate'];
          _bitrate = metrics['bitrate'];
          _networkSpeed = metrics['networkSpeed'];
        });
      }
    });
  }

  void _toggleFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = !_isFullScreen;
        if (!_isFullScreen) {
          _showControlPanel = false;
          _animationController.reverse();
        }
      });
    }
    ScreenService.toggleFullScreen(_isFullScreen);
  }

  void _toggleControlPanel() {
    if (mounted) {
      setState(() {
        _showControlPanel = !_showControlPanel;
        if (_showControlPanel) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
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

  Future<void> _enterPiPMode() async {
    debugPrint('=== PiP Button Pressed ===');

    try {
      if (_videoController != null && _videoController!.value.isInitialized) {
        // Check platform and use appropriate PiP implementation
        if (Platform.isAndroid) {
          debugPrint('Attempting to enable floating PiP on Android...');

          // Check if PiP is available first
          final bool isPipAvailable = await _floating.isPipAvailable;
          if (!isPipAvailable) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Picture-in-Picture is not available on this device',
                  ),
                ),
              );
            }
            return;
          }

          // Enable PiP using floating package with landscape aspect ratio
          final pipStatus = await _floating.enable(
            ImmediatePiP(
              aspectRatio:
                  const Rational.landscape(), // 16:9 aspect ratio for video
            ),
          );

          if (pipStatus == PiPStatus.enabled) {
            if (mounted) {
              setState(() {
                _isPiPMode = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Picture-in-Picture mode activated'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to activate Picture-in-Picture mode'),
                ),
              );
            }
          }
        } else {
          // iOS and other platforms - floating package only supports Android
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Picture-in-Picture is currently supported on Android only',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video not ready for PiP mode')),
          );
        }
      }
    } catch (e) {
      debugPrint('PiP Error: $e');

      if (mounted) {
        setState(() {
          _isPiPMode = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PiP Error: $e')));
      }
    }
  }

  Future<void> _initializeVideoController(String url) async {
    debugPrint('=== LiveStreamScreen: _initializeVideoController START ===');
    debugPrint('LiveStreamScreen: Received URL: $url');
    debugPrint(
      'LiveStreamScreen: URL validation: ${Uri.tryParse(url) != null ? "Valid" : "Invalid"}',
    );

    if (mounted) {
      setState(() {
        _connectionStatus = 'Initializing...';
        _connectionStatusColor = Colors.orange;
      });
    }

    try {
      debugPrint(
        'LiveStreamScreen: Calling VideoService.initializeVideoController with URL: $url',
      );
      await _videoService.initializeVideoController(
        url,
        (errorMessage) {
          debugPrint('=== LiveStreamScreen: VIDEO ERROR CALLBACK ===');
          debugPrint('LiveStreamScreen: Video Error received: $errorMessage');
          if (mounted) {
            setState(() {
              _connectionStatus = 'Error';
              _connectionStatusColor = Colors.red;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Video Error: $errorMessage')),
            );
          }
        },
        (videoController) {
          debugPrint('=== LiveStreamScreen: VIDEO SUCCESS CALLBACK ===');
          debugPrint(
            'LiveStreamScreen: Video controller received successfully',
          );
          debugPrint(
            'LiveStreamScreen: Video controller initialized: ${videoController.value.isInitialized}',
          );
          debugPrint(
            'LiveStreamScreen: Video duration: ${videoController.value.duration}',
          );
          debugPrint(
            'LiveStreamScreen: Video size: ${videoController.value.size}',
          );
          debugPrint(
            'LiveStreamScreen: Video playing: ${videoController.value.isPlaying}',
          );

          if (mounted) {
            setState(() {
              _videoController = videoController;
              _retryCount = 0;
              _connectionStatus = 'Connected';
              _connectionStatusColor = Colors.green;
            });
            debugPrint('LiveStreamScreen: Starting video playback');
            _videoController!.seekTo(Duration.zero);
            _videoController!.play();
            _startMetricsMonitoring();
            debugPrint('LiveStreamScreen: Video playback started');
          }
        },
      );
      debugPrint(
        '=== LiveStreamScreen: _initializeVideoController COMPLETED ===',
      );
    } catch (e) {
      debugPrint('=== LiveStreamScreen: _initializeVideoController ERROR ===');
      debugPrint('LiveStreamScreen: Initialize Video Controller Error: $e');
      debugPrint('LiveStreamScreen: Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _connectionStatus = 'Failed';
          _connectionStatusColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize video: $e')),
        );
      }
    }
  }

  void _retryStream() {
    _metricsTimer?.cancel();
    if (mounted) {
      setState(() {
        _retryCount = 0;
        _videoController?.dispose();
        _videoController = null;
        _streamStartTime = null;
        _showControlPanel = false;
        _animationController.reverse();
      });
    }
    if (mounted) {
      context.read<StreamBloc>().add(LoadStream(widget.uid, widget.domain));
    }
  }

  void _changeQuality(String quality) async {
    if (mounted) {
      setState(() {
        _currentQuality = quality;
      });
    }

    _metricsTimer?.cancel();
    await _videoService.changeQuality(
      quality,
      _basePlaybackUrl,
      _videoController,
      (videoController) {
        if (mounted) {
          setState(() {
            _videoController = videoController;
          });
        }
        _startMetricsMonitoring();
      },
      (errorMessage) {
        debugPrint('Quality Change Error: $errorMessage');
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              _connectionStatus,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // For PiP mode, show video in full screen without any UI elements
    if (_isPiPMode) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // Normal mode with AspectRatio
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  String _formatTime(Duration duration) {
    return _liveStreamHelper.formatTime(duration);
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

  Widget _buildVideoOverlay() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isLive = position >= duration - const Duration(seconds: 2);

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLive ? 'LIVE' : 'Playing',
              style: TextStyle(
                color: isLive ? Colors.red : Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quality: $_currentQuality',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(position)} / ${_formatTime(duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _buildProgressBar(),
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
                  icon: _isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  label: _isFullScreen ? 'Exit Full' : 'Full Screen',
                  onPressed: _toggleFullScreen,
                ),
                _buildControlButton(
                  icon: Icons.picture_in_picture_alt,
                  label: 'PiP',
                  onPressed: _enterPiPMode,
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

  Widget _buildProgressBar() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isLive = position >= duration - const Duration(seconds: 2);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_videoController != null && _videoController!.value.isInitialized) {
          final newPosition =
              position +
              Duration(milliseconds: (details.primaryDelta! * 100).toInt());
          final clampedPosition = newPosition < Duration.zero
              ? Duration.zero
              : (newPosition > duration ? duration : newPosition);
          _videoController!.seekTo(clampedPosition);
        }
      },
      onTapDown: (details) {
        if (_videoController != null && _videoController!.value.isInitialized) {
          final tapPosition = details.localPosition.dx;
          final screenWidth = MediaQuery.of(context).size.width;
          final newPosition = Duration(
            milliseconds: (tapPosition / screenWidth * duration.inMilliseconds)
                .toInt(),
          );
          _videoController!.seekTo(newPosition);
        }
      },
      child: Column(
        children: [
          LinearProgressIndicator(
            value: isLive
                ? null
                : position.inMilliseconds / duration.inMilliseconds,
            backgroundColor: Colors.grey,
            valueColor: AlwaysStoppedAnimation(
              isLive ? Colors.red : Colors.blue,
            ),
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  isLive ? 'LIVE' : _formatTime(duration),
                  style: TextStyle(
                    color: isLive ? Colors.red : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _connectionStatusColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _connectionStatusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _connectionStatus,
              style: TextStyle(
                color: _connectionStatusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Positioned(
      top: 60, // Move below connection status
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If in PiP mode, show only the video player without any UI
    if (_isPiPMode) {
      return Scaffold(backgroundColor: Colors.black, body: _buildVideoPlayer());
    }

    return Scaffold(
      backgroundColor:
          Colors.black, // Set background to black for immersive experience
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
          debugPrint(
            'LiveStreamScreen: BlocConsumer listener received state: ${state.runtimeType}',
          );
          debugPrint('LiveStreamScreen: Stream State: $state');

          if (state is StreamLoaded) {
            debugPrint('=== LiveStreamScreen: StreamLoaded Event ===');
            debugPrint(
              'LiveStreamScreen: Raw URL from Bloc: ${state.playbackUrl}',
            );
            debugPrint(
              'LiveStreamScreen: URL Length: ${state.playbackUrl.length} characters',
            );
            debugPrint(
              'LiveStreamScreen: Current Quality Setting: $_currentQuality',
            );

            if (mounted) {
              setState(() {
                _connectionStatus = 'Loading video...';
                _connectionStatusColor = Colors.blue;
              });
            }

            _basePlaybackUrl = state.playbackUrl;
            String url = _currentQuality == 'Auto'
                ? state.playbackUrl
                : Uri.parse(state.playbackUrl)
                      .replace(
                        queryParameters: {
                          'quality': _currentQuality.toLowerCase(),
                        },
                      )
                      .toString();

            debugPrint('LiveStreamScreen: Final URL for video player: $url');
            debugPrint(
              'LiveStreamScreen: URL modified for quality: ${url != state.playbackUrl}',
            );
            debugPrint(
              'LiveStreamScreen: About to call _initializeVideoController',
            );
            debugPrint(
              '=== LiveStreamScreen: Calling Video Initialization ===',
            );

            await _initializeVideoController(url);
          } else if (state is StreamError) {
            debugPrint('LiveStreamScreen: Stream Error: ${state.message}');
            if (mounted) {
              setState(() {
                _connectionStatus = 'Stream Error';
                _connectionStatusColor = Colors.red;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Stream Error: ${state.message}')),
              );
            }
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _connectionStatus = 'Retrying...';
                    _connectionStatusColor = Colors.orange;
                  });
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
              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint(
                              'Screen tapped - current showControlPanel: $_showControlPanel',
                            );
                            if (mounted) {
                              setState(() {
                                _showControlPanel = !_showControlPanel;
                                if (_showControlPanel) {
                                  _animationController.forward();
                                  // Hide after 5 seconds
                                  Future.delayed(
                                    const Duration(seconds: 5),
                                    () {
                                      if (mounted && _showControlPanel) {
                                        setState(() {
                                          _showControlPanel = false;
                                          _animationController.reverse();
                                        });
                                      }
                                    },
                                  );
                                } else {
                                  _animationController.reverse();
                                }
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.black,
                            child: Stack(
                              children: [
                                _buildVideoPlayer(),
                                if (!_isPiPMode) _buildVideoOverlay(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!_isPiPMode) _buildProgressBar(),
                    ],
                  ),
                  if (!_isPiPMode) _buildMetricsOverlay(),
                  if (!_isPiPMode) _buildConnectionStatus(),
                  if (!_isFullScreen && !_isPiPMode)
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
                  if (_showControlPanel && !_isPiPMode)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildControlPanel(),
                    ),
                  if (!_showControlPanel && !_isFullScreen && !_isPiPMode)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _toggleControlPanel,
                          tooltip: 'Show Controls',
                        ),
                      ),
                    ),
                  if (!_isPiPMode) _buildLiveIndicator(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
