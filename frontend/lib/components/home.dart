import 'dart:async';
import 'package:flutter/material.dart' hide Step;
import 'package:pistou/components/media_player.dart';
import 'package:pistou/models/advance_crud.dart';
import 'package:pistou/models/answer.dart';
import 'package:pistou/models/step.dart';
import 'package:pistou/models/crud.dart';
import 'package:pistou/models/user.dart';
import 'package:pistou/globals.dart';
import 'package:http/http.dart' as http;
import 'package:shake/shake.dart';
import '../i18n.dart';
import 'settings.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {Key? key,
      required this.title,
      required this.userCrud,
      required this.advanceCrud})
      : super(key: key);
  final String title;
  final Crud userCrud;
  final AdvanceCrud advanceCrud;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<Step>? _step;
  bool _hasMedia = false;
  Answer answer = Answer(
      password: App().prefs.userPassword,
      latitude: 0.0,
      longitude: 0.0,
      answer: "");

  final _answerController = TextEditingController();
  String _shakeMessage = "";

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (App().hasUser) {
      _getCurrentStep(false);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(openSettings);
    }
    ShakeDetector.autoStart(
      shakeThresholdGravity: 2.0,
      onPhoneShake: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(_shakeMessage)));
      },
    );
  }

  Future<void> _getCurrentStep(bool advance) async {
    var stepAndOutcome = advance
        ? await widget.advanceCrud.advance(context, answer)
        : await widget.advanceCrud.getCurrentStep(context);
    var s = stepAndOutcome.step;
    if (s != null) {
      setState(() {
        _answerController.text = "";
        _hasMedia = false;
        _shakeMessage = s.shakeMessage ?? tr(context, "default_shake_message");
        _step = Future.value(s);
      });
      try {
        var headResp = await http.head(Uri.parse(
            '${App().prefs.hostname}/api/steps/medias/${s.id.toString()}'));
        if (headResp.statusCode == 200) {
          setState(() {
            _hasMedia = true;
          });
        }
      } catch (e) {
        _hasMedia = false;
      }
    } else {
      // Case of unrecognized user
      if (!advance) {
        App().removeUser();
        WidgetsBinding.instance.addPostFrameCallback(openSettings);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(stepAndOutcome.outcome),
      ),
    );
  }

  Future<void> openSettings(_) async {
    final formKey = GlobalKey<FormState>();
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(tr(context, "settings")),
        content: SizedBox(
          height: 250,
          child: SettingsField(onboarding: true, formKey: formKey),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // Create an user with the given name and password
                var user = await widget.userCrud.create(User(
                    name: App().prefs.userName,
                    password: App().prefs.userPassword,
                    currentStep: 1,
                    id: 0));
                App().prefs.userId = user.id;
                if (!mounted) return;
                Navigator.pop(context, 'OK');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    hasUserOrOpenSettings(_);
  }

  void hasUserOrOpenSettings(_) {
    if (App().hasUser) {
      _getCurrentStep(false);
    } else {
      openSettings(_);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/icon_foreground_big.png',
                fit: BoxFit.contain,
                height: 30,
              ),
              const SizedBox(width: 4),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            ],
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute<void>(builder: (BuildContext context) {
                    return Settings(
                        usersCrud: APICrud<User>(), stepsCrud: APICrud<Step>());
                  }));
                  setState(() {
                    hasUserOrOpenSettings(null);
                  });
                })
          ],
        ),
        body: (App().hasUser)
            ? Center(
                child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder<Step?>(
                  future: _step,
                  builder: (context, snapshot) {
                    Widget child;
                    if (snapshot.hasData) {
                      child = Column(
                        key: ValueKey(snapshot.data!.id),
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                snapshot.data!.locationHint,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: InteractiveViewer(
                                      panEnabled: true,
                                      minScale: 1,
                                      maxScale: 10,
                                      child: Image.network(
                                        '${App().prefs.hostname}/api/steps/images/${snapshot.data!.id.toString()}',
                                        errorBuilder: (BuildContext context,
                                            Object exception,
                                            StackTrace? stackTrace) {
                                          return const Text('-');
                                        },
                                      ),
                                    )),
                              ),
                            ),
                          ),
                          if (_hasMedia)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: MediaPlayer(
                                    key: UniqueKey(),
                                    uri:
                                        '${App().prefs.hostname}/api/steps/medias/${snapshot.data!.id.toString()}'),
                              ),
                            ),
                          if (!snapshot.data!.isEnd) ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  snapshot.data!.question,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _answerController,
                                decoration: InputDecoration(
                                  icon: const Icon(Icons.help),
                                  labelText: tr(context, "answer"),
                                ),
                                onChanged: (String? value) {
                                  answer.answer = value!;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  _getCurrentStep(true);
                                },
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.my_location,
                                      color: Colors.amberAccent,
                                      size: 24.0,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(tr(context, "give_answer")),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ],
                      );
                    } else if (snapshot.hasError) {
                      child = Text('${snapshot.error}');
                    } else {
                      child = const Center(child: CircularProgressIndicator());
                    }
                    return AnimatedSwitcher(
                      switchInCurve: const Interval(
                        0.5,
                        1,
                        curve: Curves.linear,
                      ),
                      switchOutCurve: const Interval(
                        0,
                        0.5,
                        curve: Curves.linear,
                      ).flipped,
                      duration: const Duration(seconds: 1),
                      child: child,
                    );
                  },
                ),
              ))
            : null);
  }
}
