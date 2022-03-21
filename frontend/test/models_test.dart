// Import the test package and Counter class
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistou/models/step.dart';
import 'package:pistou/models/user.dart';
import 'package:pistou/models/position.dart';

void main() {
  group('Serialization', () {
    test(
        'Converting an User to json an retrieving it should give the same object',
        () async {
      final User c1 = User(id: 1, name: "test name", password: "test password");
      final c1Json = jsonEncode(c1.toJson());
      final c2 = User.fromJson(json.decode(c1Json));
      expect(c1, c2);
    });

    test(
        'Converting a Position to json an retrieving it should give the same object',
        () async {
      final Position i1 = Position(
        id: 1,
        latitude: 45.74846,
        longitude: 4.84671,
        source: "GPS",
        time: DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch),
        batteryLevel: 50,
      );
      final a1Json = jsonEncode(i1.toJson());
      final i2 = Position.fromJson(json.decode(a1Json));
      expect(i1, i2);
    });

    test(
        'Converting a Step to json an retrieving it should give the same object',
        () async {
      final Step i1 = Step(
          answer: 'test answer',
          id: 10,
          isEnd: true,
          latitude: 45.0,
          locationHint: 'test hint',
          longitude: 15.0,
          media: 'media.mp3',
          question: 'test question',
          rank: 20);
      final a1Json = jsonEncode(i1.toJson());
      final i2 = Step.fromJson(json.decode(a1Json));
      expect(i1, i2);
    });
  });
}
