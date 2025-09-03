import 'package:equatable/equatable.dart';

abstract class StreamState extends Equatable {
  const StreamState();

  @override
  List<Object> get props => [];
}

class StreamInitial extends StreamState {}

class StreamLoading extends StreamState {}

class StreamLoaded extends StreamState {
  final String playbackUrl;

  const StreamLoaded(this.playbackUrl);

  @override
  List<Object> get props => [playbackUrl];
}

class StreamError extends StreamState {
  final String message;

  const StreamError(this.message);

  @override
  List<Object> get props => [message];
}
