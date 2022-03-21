import 'dart:async';
import 'package:pistou/globals.dart';
import 'package:pistou/models/position.dart';
import 'package:aosp_location/aosp_location.dart';

Future<Position?> getPosition() async {
  await App().init();
  await App().log("Getting position...");
  try {
    final String position = await AospLocation.instance.getPositionFromGPS;
    final positions = position.split(":");
    await App().log("Got position from GPS");
    return Position(
        id: 0,
        latitude: double.parse(positions[0]),
        longitude: double.parse(positions[1]),
        batteryLevel: int.parse(positions[2]),
        source: "GPS",
        time: DateTime.now());
  } on Exception catch (e) {
    await App().log(e.toString());
  }
  return null;
}
