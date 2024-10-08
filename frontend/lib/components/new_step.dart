import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
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
import 'media_player.dart';

const elementsHeight = 500.0;

enum MediaStatus {
  none,
  available,
  loading,
}

class NewEditStep extends StatefulWidget {
  final Crud crud;
  final Step step;
  const NewEditStep({super.key, required this.crud, required this.step});

  @override
  NewEditStepState createState() => NewEditStepState();
}

final doubleOnly = RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]*)?$');

class NewEditStepState extends State<NewEditStep>
    with TickerProviderStateMixin {
  // ignore: constant_identifier_names
  static const JPG_IMAGE_QUALITY = 80;
  final _formKey = GlobalKey<FormState>();
  late bool isExisting;
  Future<Uint8List?>? imageBytes;
  bool _submitting = false;
  MediaStatus _mediaStatus = MediaStatus.none;
  PlatformFile? _mediaFile;
  Uint8List? mediaBytes;
  final int _randomId = 100000 + Random().nextInt(100000);

  TextEditingController? _latitudeController;
  TextEditingController? _longitudeController;
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    if (widget.step.id > 0) {
      _imgFromServer(widget.step.id);
      _checkHasMedia(widget.step.id);
    }
  }

  String get mediaUrl {
    var id = widget.step.id > 0 ? widget.step.id : _randomId;
    return '${App().prefs.hostname}/api/steps/medias/${id.toString()}';
  }

  Future<void> _checkHasMedia(int id) async {
    try {
      var headResp = await http.head(Uri.parse(mediaUrl));
      if (headResp.statusCode == 200) {
        setState(() {
          _mediaStatus = MediaStatus.available;
          _mediaFile =
              PlatformFile(name: headResp.headers["filename"]!, size: 0);
        });
      }
    } catch (e) {
      setState(() {
        _mediaStatus = MediaStatus.none;
        _mediaFile = null;
      });
    }
  }

  void _animatedMapMove(LatLng destLocation) {
    final latTween = Tween<double>(
        begin: mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: mapController.camera.zoom, end: mapController.camera.zoom + 1);
    var controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
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
    return encodedImage;
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
            'Authorization': "Bearer ${App().prefs.token}"
          },
          body: img);
      if (response.statusCode != 200) {
        throw Exception(response.body.toString());
      }
    } else {
      await http.delete(
        Uri.parse('${App().prefs.hostname}/api/steps/images/${id.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer ${App().prefs.token}"
        },
      );
    }
  }

  _imgFromServer(int id) async {
    final response = await http.get(
      Uri.parse('${App().prefs.hostname}/api/steps/images/${id.toString()}'),
      headers: <String, String>{'Authorization': "Bearer ${App().prefs.token}"},
    );
    if (response.statusCode == 200) {
      setState(() {
        imageBytes = Future.value(response.bodyBytes);
      });
    }
  }

  _mediaFrom() async {
    var tmpStatus = _mediaStatus;
    setState(() {
      _mediaStatus = MediaStatus.loading;
    });
    FilePickerResult? mediaFile =
        await FilePicker.platform.pickFiles(withData: true);
    if (mediaFile != null) {
      mediaBytes = mediaFile.files.first.bytes!;
      var id = widget.step.id > 0 ? widget.step.id : _randomId;
      _mediaFile = mediaFile.files.first;
      await _mediaToServer(id, _mediaFile!.extension);
      _checkHasMedia(id);
    } else {
      setState(() {
        _mediaStatus = tmpStatus;
      });
    }
  }

  Future<void> _mediaToServer(int id, String? ext) async {
    await _deleteMediaAtServer(id);
    if (mediaBytes != null) {
      final response = await http.post(
          Uri.parse(
              '${App().prefs.hostname}/api/steps/medias/${id.toString()}${ext != null ? '.$ext' : ''}'),
          headers: <String, String>{
            'Authorization': "Bearer ${App().prefs.token}"
          },
          body: mediaBytes);
      if (response.statusCode != 200) {
        throw Exception(response.body.toString());
      }
    }
  }

  Future<void> _deleteMediaAtServer(int id) async {
    await http.delete(
        Uri.parse('${App().prefs.hostname}/api/steps/medias/${id.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer ${App().prefs.token}"
        });
  }

  @override
  void dispose() {
    _latitudeController?.dispose();
    _longitudeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _latitudeController ??=
        TextEditingController(text: emptyIfZero(widget.step.latitude));
    _longitudeController ??=
        TextEditingController(text: emptyIfZero(widget.step.longitude));
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _deleteTemporarymedia();
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
                        await _deleteTemporarymedia();
                        if (!context.mounted) return;
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
                      initialValue: widget.step.shakeMessage ?? "",
                      decoration: InputDecoration(
                          labelText: tr(context, "shake_message")),
                      onChanged: (value) {
                        widget.step.shakeMessage = value != "" ? value : null;
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
                      height: elementsHeight,
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
                                initialCenter: LatLng(widget.step.latitude,
                                    widget.step.longitude),
                                minZoom: 0,
                                maxZoom: 18,
                                initialZoom: 18,
                                interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all &
                                        ~InteractiveFlag.rotate),
                              ),
                              children: <Widget>[
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: LatLng(widget.step.latitude,
                                          widget.step.longitude),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.blueAccent,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                )
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
                                          height: elementsHeight,
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
                          tr(context, "media"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    _mediaStatus == MediaStatus.loading
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                if (_mediaStatus == MediaStatus.available)
                                  Container(
                                    constraints: const BoxConstraints(
                                        maxHeight: elementsHeight),
                                    child: MediaPlayer(
                                      key: UniqueKey(),
                                      uri:
                                          "${App().prefs.hostname}/api/steps/medias/${_mediaFile!.name}",
                                      autoplay: false,
                                    ),
                                  ),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                          onPressed: () {
                                            _mediaFrom();
                                          },
                                          icon: const Icon(Icons.upload_file)),
                                      if (_mediaStatus == MediaStatus.available)
                                        IconButton(
                                            onPressed: () {
                                              setState(() {
                                                mediaBytes = null;
                                                _mediaStatus = MediaStatus.none;
                                              });
                                            },
                                            icon: const Icon(Icons.clear))
                                    ]),
                              ],
                            ),
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
                            child: _mediaStatus == MediaStatus.loading
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
                                                if (mediaBytes == null) {
                                                  await _deleteMediaAtServer(
                                                      widget.step.id);
                                                }
                                              } else {
                                                var t = await widget.crud
                                                    .create(widget.step);
                                                await _imgToServer(t.id);
                                                await _mediaToServer(t.id,
                                                    _mediaFile!.extension);
                                                await _deleteTemporarymedia();
                                              }
                                              // Do nothing on TypeError as Create respond with a null id
                                            } catch (e) {
                                              msg = e.toString();
                                            }
                                            if (!context.mounted) return;
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

  _deleteTemporarymedia() {
    http.delete(
        Uri.parse(
            '${App().prefs.hostname}/api/steps/medias/${_randomId.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer ${App().prefs.token}"
        });
  }
}

String emptyIfZero(num value) {
  return value == 0.0 ? "" : value.toString();
}
