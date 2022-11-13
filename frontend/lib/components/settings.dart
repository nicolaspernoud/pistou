import 'package:flutter/material.dart' hide Step;
import 'package:pistou/components/new_step.dart';
import 'package:pistou/models/step.dart';
import 'package:pistou/models/user.dart';
import 'package:pistou/models/crud.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:pistou/globals.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../i18n.dart';
import 'new_user.dart';

class Settings extends StatefulWidget {
  final Crud usersCrud;
  final Crud stepsCrud;
  const Settings({Key? key, required this.usersCrud, required this.stepsCrud})
      : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  String _logContent = "";
  bool _logEnabled = App().prefs.logEnabled;
  var redrawUsers = Object();
  var redrawSteps = Object();
  static const _url =
      'https://github.com/nicolaspernoud/pistou/releases/latest';
  @override
  void initState() {
    super.initState();
    refreshLog();
  }

  refreshLog() async {
    var lc = await App().getLog().join("\n");
    setState(() {
      _logContent = lc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(tr(context, "settings")), actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await widget.usersCrud.read();
                setState(() {});
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(context, "users_refreshed"))));
              })
        ]),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              SettingsField(onboarding: false, onChange: () => setState(() {})),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton(
                  onPressed: () async {
                    await canLaunchUrlString(_url)
                        ? await launchUrlString(_url)
                        : throw 'Could not launch $_url';
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr(context, "get_latest_release")),
                  ),
                ),
              ),
              if (App().hasToken) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      tr(context, "users"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                FutureBuilder<List<User>>(
                  key: ValueKey<Object>(redrawUsers),
                  future: widget.usersCrud.read(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Column(
                        children: [
                          ...snapshot.data!
                              .map((a) => Card(
                                      child: InkWell(
                                    splashColor: Colors.blue.withAlpha(30),
                                    onTap: () {
                                      _editUser(a);
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        ListTile(
                                          leading: const Icon(Icons.person),
                                          title: Text(a.name),
                                          subtitle: Text(
                                              "${tr(context, "current_step")} : ${a.currentStep}"),
                                        ),
                                      ],
                                    ),
                                  )))
                              .toList(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              color: Colors.blue,
                              onPressed: () {
                                _editUser(User(id: 0, name: "", password: ""));
                              },
                            ),
                          ),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                            removeExceptionPrefix(snapshot.error.toString())),
                      );
                    }
                    // By default, show a loading spinner.
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      tr(context, "steps"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                FutureBuilder<List<Step>>(
                  key: ValueKey<Object>(redrawSteps),
                  future: widget.stepsCrud.read(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      snapshot.data!.sort((a, b) => a.rank.compareTo(b.rank));
                      return Column(
                        children: [
                          ...snapshot.data!
                              .map((a) => Card(
                                      child: InkWell(
                                    splashColor: Colors.blue.withAlpha(30),
                                    onTap: () {
                                      _editStep(a);
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        ListTile(
                                          leading: const Icon(
                                              Icons.not_listed_location),
                                          title: Text(
                                              "${a.rank} - ${a.locationHint}"),
                                          subtitle: Text(a.question),
                                        ),
                                      ],
                                    ),
                                  )))
                              .toList(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              color: Colors.blue,
                              onPressed: () {
                                _editStep(Step(
                                  id: 0,
                                  answer: '',
                                  latitude: 0.0,
                                  locationHint: '',
                                  longitude: 0.0,
                                  media: '',
                                  question: '',
                                  rank: 1000,
                                  isEnd: false,
                                ));
                              },
                            ),
                          ),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                            removeExceptionPrefix(snapshot.error.toString())),
                      );
                    }
                    // By default, show a loading spinner.
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
                Row(
                  children: [
                    Checkbox(
                      onChanged: (bool? value) {
                        if (value != null) {
                          App().prefs.logEnabled = value;
                          setState(() {
                            _logEnabled = value;
                          });
                        }
                      },
                      value: _logEnabled,
                    ),
                    Text(tr(context, "enable_log")),
                  ],
                ),
                if (_logEnabled)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    color: Colors.black,
                    onPressed: () {
                      App().clearLog();
                      refreshLog();
                    },
                  ),
                if (_logEnabled)
                  TextFormField(
                    key: Key(_logContent),
                    initialValue: _logContent,
                    maxLines: null,
                  )
              ],
            ],
          ),
        )));
  }

  String removeExceptionPrefix(String error) {
    return error.replaceFirst("Exception: ", "");
  }

  Future<void> _editUser(User u) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (BuildContext context) {
      return NewEditUser(crud: APICrud<User>(), user: u);
    }));
    setState(() {
      redrawUsers = Object();
    });
  }

  Future<void> _editStep(Step s) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (BuildContext context) {
      return NewEditStep(crud: APICrud<Step>(), step: s);
    }));
    setState(() {
      redrawSteps = Object();
    });
  }
}

class SettingsField extends StatelessWidget {
  final bool onboarding;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onChange;

  const SettingsField(
      {Key? key, required this.onboarding, this.formKey, this.onChange})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          if (!kIsWeb || kDebugMode)
            TextFormField(
              initialValue: App().prefs.hostname,
              //initialValue: App().prefs.hostname != "" ? App().prefs.hostname : "http://10.0.2.2:8080-",
              decoration: InputDecoration(labelText: tr(context, "hostname")),
              onChanged: (text) {
                App().prefs.hostname = text;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return tr(context, "please_enter_some_text");
                }
                return null;
              },
              key: const Key("hostnameField"),
            ),
          if (onboarding)
            TextFormField(
              initialValue: App().prefs.userName,
              decoration: InputDecoration(labelText: tr(context, "username")),
              onChanged: (text) {
                App().prefs.userName = text;
              },
              key: const Key("userNameField"),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return tr(context, "please_enter_some_text");
                }
                return null;
              },
            ),
          TextFormField(
            initialValue: App().prefs.userPassword,
            decoration: InputDecoration(labelText: tr(context, "password")),
            onChanged: (text) {
              App().prefs.userPassword = text;
            },
            key: const Key("userPasswordField"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return tr(context, "please_enter_some_text");
              }
              return null;
            },
          ),
          TextFormField(
            //initialValue: App().prefs.token != "" ? App().prefs.token : "token-",
            initialValue: App().prefs.token,
            decoration: InputDecoration(labelText: tr(context, "token")),
            onChanged: (text) {
              App().prefs.token = text;
              if (onChange != null) {
                onChange!();
              }
            },
            key: const Key("tokenField"),
          ),
        ],
      ),
    );
  }
}
