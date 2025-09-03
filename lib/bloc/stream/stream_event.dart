import 'package:equatable/equatable.dart';

abstract class StreamEvent extends Equatable {
  const StreamEvent();

  @override
  List<Object> get props => [];
}

class LoadStream extends StreamEvent {
  final String uid;
  final String domain;

  const LoadStream(this.uid, this.domain);

  @override
  List<Object> get props => [uid, domain];
}
