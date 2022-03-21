import 'dart:async';

import 'package:flutter/material.dart' hide Step;
import 'package:pistou/models/advance_crud.dart';
import 'package:pistou/models/answer.dart';
import 'package:pistou/models/step.dart';
import 'package:pistou/models/crud.dart';
import 'package:pistou/models/user.dart';
import 'package:http/http.dart' as http;

import 'package:pistou/globals.dart';
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
  Answer answer = Answer(
      password: App().prefs.userPassword,
      latitude: 0.0,
      longitude: 0.0,
      answer: "");

  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (App().hasUser) {
      _getCurrentStep();
    } else {
      WidgetsBinding.instance?.addPostFrameCallback(openSettings);
    }
  }

  Future<void> _getCurrentStep() async {
    var stepAndOutcome = await widget.advanceCrud.getCurrentStep(context);
    var s = stepAndOutcome.step;
    if (s != null) {
      setState(() {
        _step = Future.value(s);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(stepAndOutcome.outcome),
      ),
    );
  }

  Future<void> _advance() async {
    var stepAndOutcome = await widget.advanceCrud.advance(context, answer);
    var s = stepAndOutcome.step;
    if (s != null) {
      setState(() {
        _step = Future.value(s);
        _answerController.text = "";
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(stepAndOutcome.outcome),
      ),
    );
  }

  Future<void> openSettings(_) async {
    final _formKey = GlobalKey<FormState>();
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(tr(context, "settings")),
        content: SizedBox(
          child: SettingsField(onboarding: true, formKey: _formKey),
          height: 250,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Create an user with the given name and password
                var user = await widget.userCrud.create(User(
                    name: App().prefs.userName,
                    password: App().prefs.userPassword,
                    currentStep: 1,
                    id: 0));
                App().prefs.userId = user.id;
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
      _getCurrentStep();
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
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Step?>(
                  future: _step,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const Icon(Icons.not_listed_location, size: 40),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  snapshot.data!.locationHint,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: FutureBuilder<http.Response?>(
                                  future: http.get(Uri.parse(
                                      '${App().prefs.hostname}/api/common/steps/images/${snapshot.data!.id.toString()}')),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data!.statusCode == 200 &&
                                        snapshot.data != null) {
                                      return Container(
                                        constraints: const BoxConstraints(
                                          maxHeight: 500,
                                        ),
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                            child: Image.memory(
                                              snapshot.data!.bodyBytes,
                                              fit: BoxFit.contain,
                                            )),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            if (!snapshot.data!.isEnd) ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    snapshot.data!.question,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
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
                                padding: const EdgeInsets.all(16.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _advance();
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
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Text('${snapshot.error}');
                    }
                    // By default, show a loading spinner.
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ))
            : null);
  }
}
