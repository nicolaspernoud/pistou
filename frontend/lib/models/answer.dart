class Answer {
  Answer({
    required this.password,
    required this.latitude,
    required this.longitude,
    required this.answer,
  });
  late String password;
  late double latitude;
  late double longitude;
  late String answer;

  Answer.fromJson(Map<String, dynamic> json) {
    password = json['password'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    answer = json['answer'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['password'] = password;
    _data['latitude'] = latitude;
    _data['longitude'] = longitude;
    _data['answer'] = answer;
    return _data;
  }
}
