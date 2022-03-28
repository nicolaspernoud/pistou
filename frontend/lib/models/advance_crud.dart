import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:pistou/globals.dart';
import 'package:pistou/i18n.dart';
import 'package:pistou/models/answer.dart';
import 'package:pistou/models/mock_api.dart';
import 'package:pistou/models/new_position.dart';
import 'package:pistou/models/step.dart';

class AdvanceCrud {
  late final Client client;

  final String route = "user";

  String get base => App().prefs.hostname + "/api";
  String get token => App().prefs.token;

  AdvanceCrud() {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      client = MockAPI().client;
    } else {
      client = Client();
    }
  }

  Future<AdvanceCrudResponse> getCurrentStep(context) async {
    try {
      var base = App().prefs.hostname + "/api";
      var route = "users/${App().prefs.userId}/current_step";
      final response =
          await client.get(Uri.parse('$base/$route'), headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      });
      if (response.statusCode == 200) {
        return AdvanceCrudResponse(
            step: Step.fromJson(json.decode(utf8.decode(response.bodyBytes))),
            outcome: tr(context, "starting_game"));
      }
      return AdvanceCrudResponse(
          step: null, outcome: tr(context, "confirm_your_id"));
    } on Exception catch (e) {
      return AdvanceCrudResponse(step: null, outcome: e.toString());
    }
  }

  Future<AdvanceCrudResponse> advance(context, Answer answer) async {
    try {
      var position = await getPosition();
      answer.latitude = position!.latitude;
      answer.longitude = position.longitude;
      answer.password = App().prefs.userPassword;
      var base = App().prefs.hostname + "/api";
      var route = "users/${App().prefs.userId}/advance";
      final response = await client.post(Uri.parse('$base/$route'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(answer.toJson()));
      if (response.statusCode == 200) {
        return AdvanceCrudResponse(
            step: Step.fromJson(json.decode(utf8.decode(response.bodyBytes))),
            outcome: tr(context, "going_next_step"));
      } else if (response.statusCode == 403) {
        return AdvanceCrudResponse(
            step: null, outcome: tr(context, "wrong_password"));
      } else if (response.statusCode == 406) {
        Map<String, dynamic> r = jsonDecode(response.body);
        String outcome = "";
        if (r["type"] == "WrongPlace") {
          outcome = MyLocalizations.of(context)!.wrongPlace(r["distance"]);
        } else if (r["type"] == "WrongAnswer") {
          outcome = tr(context, "wrong_answer");
        }
        return AdvanceCrudResponse(step: null, outcome: outcome);
      } else if (response.statusCode == 404) {
        return AdvanceCrudResponse(
            step: null, outcome: tr(context, "no_more_steps"));
      }
      return AdvanceCrudResponse(step: null, outcome: "bad_response_code");
    } on GPSException {
      return AdvanceCrudResponse(step: null, outcome: tr(context, "gps_error"));
    } on Exception catch (e) {
      return AdvanceCrudResponse(step: null, outcome: e.toString());
    }
  }
}

class AdvanceCrudResponse {
  late Step? step;
  late String outcome;

  AdvanceCrudResponse({required this.step, required this.outcome});
}
