import 'package:flutter/material.dart' hide Step;
import 'package:pistou/components/home.dart';
import 'dart:async';
import 'package:pistou/globals.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pistou/i18n.dart';
import 'package:pistou/models/advance_crud.dart';
import 'package:pistou/models/crud.dart';
import 'package:pistou/models/user.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await App().init();
  if (!kIsWeb) {
    while (!(await Permission.location.status.isGranted)) {
      await [
        Permission.location,
      ].request();
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pistou',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MyHomePage(
          title: 'Pistou',
          userCrud: APICrud<User>(),
          advanceCrud: AdvanceCrud()),
      localizationsDelegates: const [
        MyLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
      ],
    );
  }
}
