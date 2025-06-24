import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pistou/models/preferences.dart';

class App {
  Preferences prefs = Preferences();
  App._privateConstructor();

  static final App _instance = App._privateConstructor();

  factory App() {
    return _instance;
  }

  bool get hasToken {
    return prefs.token != "";
  }

  bool get hasUser {
    return prefs.userId > 0;
  }

  void removeUser() {
    prefs.userId = 0;
  }

  Future<void> log(String v) async {
    await prefs.addToLog(v);
  }

  List<String> getLog() {
    return prefs.log;
  }

  void clearLog() {
    prefs.clearLog();
  }

  Future init() async {
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      await prefs.read();
    }
  }
}
