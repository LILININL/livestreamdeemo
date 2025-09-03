import 'package:equatable/equatable.dart';

class StreamModel extends Equatable {
  final String uid;
  final String domain;

  const StreamModel({required this.uid, required this.domain});

  @override
  List<Object> get props => [uid, domain];
}
