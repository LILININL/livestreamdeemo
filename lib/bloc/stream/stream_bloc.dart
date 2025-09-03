import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_event.dart';
import 'package:livestreamdeemo/bloc/stream/stream_state.dart';
import 'package:livestreamdeemo/repositories/stream_repository.dart';

class StreamBloc extends Bloc<StreamEvent, StreamState> {
  final StreamRepository streamRepository;

  StreamBloc(this.streamRepository) : super(StreamInitial()) {
    on<LoadStream>(_onLoadStream);
  }

  Future<void> _onLoadStream(
    LoadStream event,
    Emitter<StreamState> emit,
  ) async {
    emit(StreamLoading());
    try {
      final playbackUrl = await streamRepository.getPlaybackUrl(
        event.uid,
        event.domain,
      );
      emit(StreamLoaded(playbackUrl));
    } catch (e) {
      emit(StreamError(e.toString()));
    }
  }
}
