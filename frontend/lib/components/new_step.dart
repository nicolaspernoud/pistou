import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pistou/globals.dart';
import 'package:pistou/models/crud.dart';
import 'package:pistou/models/new_position.dart';
import 'package:pistou/models/step.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

import '../i18n.dart';

enum SoundStatus {
  none,
  available,
  loading,
}

class NewEditStep extends StatefulWidget {
  final Crud crud;
  final Step step;
  const NewEditStep({Key? key, required this.crud, required this.step})
      : super(key: key);

  @override
  _NewEditStepState createState() => _NewEditStepState();
}

final doubleOnly = RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]*)?$');

class _NewEditStepState extends State<NewEditStep>
    with TickerProviderStateMixin {
  // ignore: constant_identifier_names
  static const JPG_IMAGE_QUALITY = 80;
  final _formKey = GlobalKey<FormState>();
  late bool isExisting;
  Future<Uint8List?>? imageBytes;
  bool _submitting = false;
  AudioPlayer audioPlayer = AudioPlayer();
  SoundStatus _soundStatus = SoundStatus.none;
  Uint8List? soundBytes;
  final int _randomId = 100000 + Random().nextInt(100000);

  TextEditingController? _latitudeController;
  TextEditingController? _longitudeController;
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    audioPlayer.setLoopMode(LoopMode.one);
    mapController = MapController();
    if (widget.step.id > 0) {
      _imgFromServer(widget.step.id);
      _setPlayerUrl(widget.step.id);
    }
  }

  Future<void> _setPlayerUrl(int id) async {
    // Dummy loading to force cache flush
    try {
      await audioPlayer.setUrl('${App().prefs.hostname}/api/steps/sounds/dummy',
          preload: false);
    } on Exception catch (_) {}
    try {
      await audioPlayer
          .setUrl('${App().prefs.hostname}/api/steps/sounds/${id.toString()}');
      setState(() {
        _soundStatus = SoundStatus.available;
      });
    } catch (e) {
      setState(() {
        _soundStatus = SoundStatus.none;
      });
    }
  }

  void _animatedMapMove(LatLng destLocation) {
    final _latTween = Tween<double>(
        begin: mapController.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(
        begin: mapController.center.longitude, end: destLocation.longitude);
    final _zoomTween =
        Tween<double>(begin: mapController.zoom, end: mapController.zoom + 1);
    var controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      mapController.move(
          LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)),
          _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  _imgFrom(ImageSource source) async {
    final temp = await ImagePicker().pickImage(
        source: source, imageQuality: JPG_IMAGE_QUALITY, maxWidth: 1280);
    if (temp != null) {
      setState(() {
        imageBytes = temp.readAsBytes();
      });
    }
  }

  static Future<Uint8List> bakeOrientation(Uint8List img) async {
    final capturedImage = image.decodeImage(img);
    final orientedImage = image.bakeOrientation(capturedImage!);
    final encodedImage =
        image.encodeJpg(orientedImage, quality: JPG_IMAGE_QUALITY);
    return encodedImage as Uint8List;
  }

  Future<void> _imgToServer(int id) async {
    Uint8List? img = await imageBytes;
    if (imageBytes != null && img != null) {
      // Bake orientation on devices only as it is very slow and web does not support compute !!!
      if (!kIsWeb) {
        img = await compute(bakeOrientation, img);
      }
      final response = await http.post(
          Uri.parse(
              '${App().prefs.hostname}/api/steps/images/${id.toString()}'),
          headers: <String, String>{
            'Authorization': "Bearer " + App().prefs.token
          },
          body: img);
      if (response.statusCode != 200) {
        throw Exception(response.body.toString());
      }
    } else {
      await http.delete(
        Uri.parse('${App().prefs.hostname}/api/steps/images/${id.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer " + App().prefs.token
        },
      );
    }
  }

  _imgFromServer(int id) async {
    final response = await http.get(
      Uri.parse('${App().prefs.hostname}/api/steps/images/${id.toString()}'),
      headers: <String, String>{'Authorization': "Bearer " + App().prefs.token},
    );
    if (response.statusCode == 200) {
      setState(() {
        imageBytes = Future.value(response.bodyBytes);
      });
    }
  }

  _soundFrom() async {
    var tmpStatus = _soundStatus;
    setState(() {
      _soundStatus = SoundStatus.loading;
    });
    FilePickerResult? audioFile =
        await FilePicker.platform.pickFiles(withData: true);
    if (audioFile != null) {
      soundBytes = audioFile.files.first.bytes!;
      var id = widget.step.id > 0 ? widget.step.id : _randomId;
      await _soundToServer(id);
      _setPlayerUrl(id);
    } else {
      setState(() {
        _soundStatus = tmpStatus;
      });
    }
  }

  Future<void> _soundToServer(int id) async {
    if (soundBytes != null) {
      final response = await http.post(
          Uri.parse(
              '${App().prefs.hostname}/api/steps/sounds/${id.toString()}'),
          headers: <String, String>{
            'Authorization': "Bearer " + App().prefs.token
          },
          body: soundBytes);
      if (response.statusCode != 200) {
        throw Exception(response.body.toString());
      }
    } else if (_soundStatus == SoundStatus.none) {
      http.delete(
        Uri.parse('${App().prefs.hostname}/api/steps/sounds/${id.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer " + App().prefs.token
        },
      );
    }
  }

  @override
  void dispose() {
    _latitudeController?.dispose();
    _longitudeController?.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _latitudeController ??=
        TextEditingController(text: emptyIfZero(widget.step.latitude));
    _longitudeController ??=
        TextEditingController(text: emptyIfZero(widget.step.longitude));
    return WillPopScope(
      onWillPop: () async {
        await _deleteTemporarySound();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: widget.step.id > 0
              ? Text('${tr(context, "edit_step")} (id: ${widget.step.id})')
              : Text(tr(context, "new_step")),
          actions: widget.step.id > 0
              ? [
                  IconButton(
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () async {
                        await widget.crud.delete(widget.step.id);
                        await _deleteTemporarySound();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(tr(context, "step_deleted"))));
                      })
                ]
              : null,
        ),
        body: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration:
                          InputDecoration(labelText: tr(context, "rank")),
                      initialValue: widget.step.rank.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (value) {
                        var v = int.tryParse(value);
                        if (v != null) {
                          widget.step.rank = v;
                        }
                      },
                    ),
                    TextFormField(
                      initialValue: widget.step.locationHint,
                      decoration: InputDecoration(
                          labelText: tr(context, "location_hint")),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr(context, "please_enter_some_text");
                        }
                        return null;
                      },
                      onChanged: (value) {
                        widget.step.locationHint = value;
                      },
                    ),
                    TextFormField(
                      initialValue: widget.step.question,
                      decoration:
                          InputDecoration(labelText: tr(context, "question")),
                      // The validator receives the text that the step has entered.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr(context, "please_enter_some_text");
                        }
                        return null;
                      },
                      onChanged: (value) {
                        widget.step.question = value;
                      },
                    ),
                    TextFormField(
                      initialValue: widget.step.answer,
                      decoration:
                          InputDecoration(labelText: tr(context, "answer")),
                      // The validator receives the text that the step has entered.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr(context, "please_enter_some_text");
                        }
                        return null;
                      },
                      onChanged: (value) {
                        widget.step.answer = value;
                      },
                    ),
                    TextFormField(
                      controller: _latitudeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: tr(context, "latitude"),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.my_location),
                              onPressed: () async {
                                var pos = await getPosition();
                                _updateMap(pos!.latitude, pos.longitude, true);
                              })),
                      // The validator receives the text that the step has entered.
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(doubleOnly)
                      ],
                      onChanged: (text) {
                        var value = double.tryParse(text);
                        if (value != null) {
                          widget.step.latitude = value;
                          _updateMap(widget.step.latitude,
                              widget.step.longitude, false);
                        } else {
                          widget.step.latitude = 0;
                        }
                      },
                    ),
                    TextFormField(
                      controller: _longitudeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr(context, "longitude"),
                      ),
                      // The validator receives the text that the step has entered.
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(doubleOnly)
                      ],
                      onChanged: (text) {
                        var value = double.tryParse(text);
                        if (value != null) {
                          widget.step.longitude = value;
                          _updateMap(widget.step.latitude,
                              widget.step.longitude, false);
                        } else {
                          widget.step.longitude = 0;
                        }
                      },
                    ),
                    SizedBox(
                      height: 350,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20.0),
                          child: FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                  onTap: (tapPosition, point) {
                                    _updateMap(
                                        point.latitude, point.longitude, true);
                                  },
                                  center: LatLng(widget.step.latitude,
                                      widget.step.longitude),
                                  minZoom: 0,
                                  maxZoom: 18,
                                  enableScrollWheel: true,
                                  interactiveFlags: InteractiveFlag.all &
                                      ~InteractiveFlag.rotate),
                              children: <Widget>[
                                TileLayerWidget(
                                  options: TileLayerOptions(
                                    urlTemplate:
                                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    subdomains: ['a', 'b', 'c'],
                                  ),
                                ),
                                MarkerLayerWidget(
                                    options: MarkerLayerOptions(
                                  markers: [
                                    Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: LatLng(widget.step.latitude,
                                          widget.step.longitude),
                                      builder: (ctx) => const Icon(
                                        Icons.location_on,
                                        color: Colors.blueAccent,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ))
                              ]),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(tr(context, "is_end")),
                        Checkbox(
                            value: widget.step.isEnd,
                            onChanged: (value) => setState(() {
                                  widget.step.isEnd = value!;
                                })),
                      ],
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Image",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FutureBuilder<Uint8List?>(
                          future: imageBytes,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20.0),
                                      child: InkWell(
                                        onTap: () {
                                          _imgFrom(ImageSource.camera);
                                        },
                                        child: Image.memory(
                                          snapshot.data!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                      onPressed: () {
                                        setState(() {
                                          imageBytes = Future.value(null);
                                        });
                                      },
                                      icon: const Icon(Icons.clear))
                                ],
                              );
                            } else if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      _imgFrom(ImageSource.camera);
                                    },
                                    icon: const Icon(Icons.camera_alt)),
                                IconButton(
                                    onPressed: () {
                                      _imgFrom(ImageSource.gallery);
                                    },
                                    icon: const Icon(Icons.upload_file)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr(context, "sound"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    _soundStatus == SoundStatus.loading
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_soundStatus == SoundStatus.available)
                                    IconButton(
                                        onPressed: () {
                                          setState(() {
                                            if (audioPlayer.playing) {
                                              audioPlayer.stop();
                                            } else {
                                              audioPlayer.play();
                                            }
                                          });
                                        },
                                        icon: audioPlayer.playing
                                            ? const Icon(Icons.pause)
                                            : const Icon(Icons.play_arrow)),
                                  IconButton(
                                      onPressed: () {
                                        _soundFrom();
                                      },
                                      icon: const Icon(Icons.upload_file)),
                                  if (_soundStatus == SoundStatus.available)
                                    IconButton(
                                        onPressed: () {
                                          setState(() {
                                            audioPlayer.stop();
                                            soundBytes = null;
                                            _soundStatus = SoundStatus.none;
                                          });
                                        },
                                        icon: const Icon(Icons.clear))
                                ]),
                          ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: SizedBox(
                        width: 140,
                        height: 50,
                        child: Center(
                          child: AnimatedSwitcher(
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
                            duration: const Duration(milliseconds: 500),
                            child: _soundStatus == SoundStatus.loading
                                ? const SizedBox.shrink()
                                : !_submitting
                                    ? ElevatedButton(
                                        onPressed: () async {
                                          // Validate returns true if the form is valid, or false otherwise.
                                          if (_formKey.currentState!
                                              .validate()) {
                                            setState(() {
                                              _submitting = true;
                                            });
                                            var msg =
                                                tr(context, "step_created");
                                            try {
                                              if (widget.step.id > 0) {
                                                await widget.crud
                                                    .update(widget.step);
                                                await _imgToServer(
                                                    widget.step.id);
                                                await _soundToServer(
                                                    widget.step.id);
                                              } else {
                                                var t = await widget.crud
                                                    .create(widget.step);
                                                await _imgToServer(t.id);
                                                await _soundToServer(t.id);
                                                await _deleteTemporarySound();
                                              }
                                              // Do nothing on TypeError as Create respond with a null id
                                            } catch (e) {
                                              msg = e.toString();
                                            }
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(content: Text(msg)),
                                            );
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(tr(context, "submit")),
                                        ),
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ),
      ),
    );
  }

  void _updateMap(double lat, double long, bool updateFields) {
    setState(() {
      widget.step.latitude = lat;
      widget.step.longitude = long;
    });
    _animatedMapMove(LatLng(widget.step.latitude, widget.step.longitude));
    if (updateFields) {
      _latitudeController?.text = emptyIfZero(widget.step.latitude);
      _longitudeController?.text = emptyIfZero(widget.step.longitude);
    }
  }

  _deleteTemporarySound() {
    http.delete(
        Uri.parse(
            '${App().prefs.hostname}/api/steps/sounds/${_randomId.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer " + App().prefs.token
        });
  }
}

String emptyIfZero(num value) {
  return value == 0.0 ? "" : value.toString();
}
