abstract class StreamState {}

class StreamInitial extends StreamState {}

class StreamLoading extends StreamState {}

class StreamLoaded extends StreamState {
  final String playbackUrl;

  StreamLoaded(this.playbackUrl);
}

class StreamError extends StreamState {
  final String message;

  StreamError(this.message);
}
