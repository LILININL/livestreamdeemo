import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:livestreamdeemo/repositories/stream_repository.dart';
import 'stream_event.dart';
import 'stream_state.dart';

class StreamBloc extends Bloc<StreamEvent, StreamState> {
  final StreamRepository streamRepository;

  StreamBloc({required this.streamRepository}) : super(StreamInitial()) {
    on<LoadStream>(_onLoadStream);
  }

  Future<void> _onLoadStream(
    LoadStream event,
    Emitter<StreamState> emit,
  ) async {
    debugPrint(
      'StreamBloc: LoadStream event received - uid: ${event.uid}, domain: ${event.domain}',
    );
    emit(StreamLoading());

    try {
      // Use CloudflareService to get the actual playback URL
      debugPrint('StreamBloc: Getting playback URL from CloudflareService');
      final playbackUrl = await streamRepository.getPlaybackUrl(
        event.uid,
        event.domain,
      );

      debugPrint('StreamBloc: Received playback URL: $playbackUrl');

      debugPrint('StreamBloc: Emitting StreamLoaded state');
      emit(StreamLoaded(playbackUrl));
    } catch (e) {
      debugPrint('StreamBloc: Error occurred: $e');
      emit(StreamError('Failed to load stream: ${e.toString()}'));
    }
  }
}
