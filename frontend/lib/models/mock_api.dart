import 'package:http/http.dart';
import 'package:http/testing.dart';

class MockAPI {
  late final Client client;
  MockAPI() {
    client = MockClient((request) async {
      switch (request.url.toString()) {
        case 'http://test/api/users/1/current_step':
          return Response('''
              {"id":1,"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"what is the color of the grass?","answer":"green","is_end":false}
              ''', 200);
        case 'http://test/api/users':
          return Response('''
              {"id":1,"name":"Patched test name","password":"Patched test password","current_step":2}
              ''', 201);
        default:
          return Response('Not Found', 404);
      }
    });
  }
}
