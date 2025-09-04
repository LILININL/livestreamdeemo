abstract class StreamEvent {}

class LoadStream extends StreamEvent {
  final String uid;
  final String domain;

  LoadStream(this.uid, this.domain);
}
