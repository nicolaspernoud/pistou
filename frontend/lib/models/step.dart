import 'crud.dart';

class Step extends Serialisable {
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Step) {
      // Define the subset of properties to compare
      final subset = [
        () => id == other.id,
        () => rank == other.rank,
        () => latitude == other.latitude,
        () => longitude == other.longitude,
        () => locationHint == other.locationHint,
        () => question == other.question,
        () => shakeMessage == other.shakeMessage,
        () => answer == other.answer,
        () => isEnd == other.isEnd,
      ];
      // Compare each property in the subset
      return subset.every((comparison) => comparison());
    }
    return false;
  }

  @override
  int get hashCode {
    // Use only the subset of properties for the hash code
    return Object.hash(id, rank, latitude, longitude, locationHint, question,
        shakeMessage, answer, isEnd);
  }
}
