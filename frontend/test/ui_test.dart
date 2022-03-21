import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:pistou/components/home.dart';
import 'package:pistou/globals.dart';
import 'package:pistou/i18n.dart';
import 'package:pistou/models/advance_crud.dart';
import 'package:pistou/models/crud.dart';
import 'package:pistou/models/user.dart';

Future<void> main() async {
  testWidgets('Basic app opening tests', (WidgetTester tester) async {
    // Initialize configuration
    await App().init();
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
            title: 'Pistou',
            userCrud: APICrud<User>(),
            advanceCrud: AdvanceCrud()),
        localizationsDelegates: const [
          MyLocalizationsDelegate(),
        ],
      ),
    );

    // Check that the app title is displayed
    expect(find.text('Pistou'), findsOneWidget);
    await tester.pump();
    // Fill user infos
    await tester.enterText(
        find.byKey(const Key("hostnameField")), 'http://test');
    await tester.enterText(find.byKey(const Key("userNameField")), 'my name');
    await tester.enterText(
        find.byKey(const Key("userPasswordField")), 'my password');
    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();
    // To print the widget tree :
    //debugDumpApp();
    // Check that we display the location hint
    expect(find.text("go there after"), findsOneWidget);
  });
}
