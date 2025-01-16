import 'package:pistou/models/crud.dart';

class User extends Serialisable {
  String name;
  String password;
  int? currentStep;

  User(
      {required super.id,
      required this.name,
      required this.password,
      this.currentStep});

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'name': name,
      'password': password,
      'current_step': currentStep
    };
  }

  factory User.fromJson(Map<String, dynamic> data) {
    return User(
      id: data['id'],
      name: data['name'],
      password: "",
      currentStep: data['current_step'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is User) {
      // Define the subset of properties to compare
      final subset = [
        () => id == other.id,
        () => name == other.name,
        () => currentStep == other.currentStep,
      ];
      // Compare each property in the subset
      return subset.every((comparison) => comparison());
    }
    return false;
  }

  @override
  int get hashCode {
    // Use only the subset of properties for the hash code
    return Object.hash(id, name, currentStep);
  }
}
