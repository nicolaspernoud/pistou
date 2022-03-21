import 'package:equatable/equatable.dart';

import 'crud.dart';

class Step extends Serialisable with EquatableMixin {
  int rank;
  double latitude;
  double longitude;
  String locationHint;
  String question;
  String answer;
  String media;
  bool isEnd;

  Step(
      {required id,
      required this.rank,
      required this.latitude,
      required this.longitude,
      required this.locationHint,
      required this.question,
      required this.answer,
      required this.media,
      required this.isEnd})
      : super(id: id);

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'rank': rank,
      'latitude': latitude,
      'longitude': longitude,
      'location_hint': locationHint,
      'question': question,
      'answer': answer,
      'media': media,
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
        answer: json['answer'],
        media: json['media'],
        isEnd: json['is_end']);
  }

  @override
  List<Object> get props {
    return [
      id,
      rank,
      latitude,
      longitude,
      locationHint,
      question,
      answer,
      media,
      isEnd
    ];
  }

  @override
  bool get stringify => true;
}
