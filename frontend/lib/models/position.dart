import 'crud.dart';

class Position extends Serialisable {
  double latitude;
  double longitude;
  String source;
  DateTime time;
  int batteryLevel;

  Position(
      {required super.id,
      required this.latitude,
      required this.longitude,
      required this.source,
      required this.batteryLevel,
      required this.time});

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      'battery_level': batteryLevel,
      'time': time.millisecondsSinceEpoch
    };
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
        id: json['id'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        source: json['source'],
        batteryLevel: json['battery_level'],
        time: json['time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['time'])
            : DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Position) {
      // Define the subset of properties to compare
      final subset = [
        () => id == other.id,
        () => latitude == other.latitude,
        () => longitude == other.longitude,
        () => source == other.source,
        () => batteryLevel == other.batteryLevel,
        () => time == other.time
      ];
      // Compare each property in the subset
      return subset.every((comparison) => comparison());
    }
    return false;
  }

  @override
  int get hashCode {
    // Use only the subset of properties for the hash code
    return Object.hash(id, latitude, longitude, source, batteryLevel, time);
  }
}
