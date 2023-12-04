import 'package:equatable/equatable.dart';

import 'crud.dart';

class Step extends Serialisable with EquatableMixin {
  int rank;
  double latitude;
  double longitude;
  String locationHint;
  String question;
  String? shakeMessage;
  String answer;
  bool isEnd;

  Step(
      {required super.id,
      required this.rank,
      required this.latitude,
      required this.longitude,
      required this.locationHint,
      required this.question,
      this.shakeMessage,
      required this.answer,
      required this.isEnd});

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'rank': rank,
      'latitude': latitude,
      'longitude': longitude,
      'location_hint': locationHint,
      'question': question,
      if (shakeMessage != null) 'shake_message': shakeMessage,
      'answer': answer,
      'is_end': isEnd
    };
  }

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
        id: json['id'],
        rank: json['rank'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        locationHint: json['location_hint'],
        question: json['question'],
        shakeMessage: json['shake_message'],
        answer: json['answer'],
        isEnd: json['is_end']);
  }

  @override
  List<Object> get props {
    var props = [
      id,
      rank,
      latitude,
      longitude,
      locationHint,
      question,
      answer,
      isEnd
    ];
    if (shakeMessage != null) props.add(shakeMessage!);
    return props;
  }

  @override
  bool get stringify => true;
}
