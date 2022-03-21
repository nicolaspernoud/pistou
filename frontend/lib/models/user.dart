import 'package:pistou/models/crud.dart';
import 'package:equatable/equatable.dart';

class User extends Serialisable with EquatableMixin {
  String name;
  String password;
  int? currentStep;

  User(
      {required id,
      required this.name,
      required this.password,
      this.currentStep})
      : super(id: id);

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
  List<Object> get props {
    return [id, name];
  }

  @override
  bool get stringify => true;
}
