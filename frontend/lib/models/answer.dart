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
    final data = <String, dynamic>{};
    data['password'] = password;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['answer'] = answer;
    return data;
  }
}
