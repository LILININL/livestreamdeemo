import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_state.dart';
import 'package:livestreamdeemo/presentation/widgets/video_overlay.dart';
import 'package:livestreamdeemo/presentation/widgets/progress_bar.dart';
import 'package:livestreamdeemo/presentation/widgets/video_player_widget.dart';

class LiveStreamScreen extends StatelessWidget {
  final String uid;
  final String domain;

  const LiveStreamScreen({super.key, required this.uid, required this.domain});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<StreamBloc, StreamState>(
        listener: (context, state) {},
        builder: (context, state) {
          return Stack(
            children: [
              Center(child: const VideoPlayerWidget(controller: null)),
              VideoOverlay(),
              ProgressBar(),
            ],
          );
        },
      ),
    );
  }
}
