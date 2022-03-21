import 'dart:typed_data';

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

import '../i18n.dart';

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
  bool submitting = false;

  TextEditingController? _latitudeController;
  TextEditingController? _longitudeController;
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    if (widget.step.id > 0) {
      _imgFromServer(widget.step.id);
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

  _imgFromCamera() async {
    final temp = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: JPG_IMAGE_QUALITY,
        maxWidth: 1280);
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
              '${App().prefs.hostname}/api/admin/steps/images/${id.toString()}'),
          headers: <String, String>{
            'Authorization': "Bearer " + App().prefs.token
          },
          body: img);
      if (response.statusCode != 200) {
        throw Exception(response.body.toString());
      }
    } else {
      await http.delete(
        Uri.parse(
            '${App().prefs.hostname}/api/admin/steps/images/${id.toString()}'),
        headers: <String, String>{
          'Authorization': "Bearer " + App().prefs.hostname
        },
      );
    }
  }

  _imgFromServer(int id) async {
    final response = await http.get(
      Uri.parse(
          '${App().prefs.hostname}/api/common/steps/images/${id.toString()}'),
      headers: <String, String>{'Authorization': "Bearer " + App().prefs.token},
    );
    if (response.statusCode == 200) {
      setState(() {
        imageBytes = Future.value(response.bodyBytes);
      });
    }
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
    return Scaffold(
      appBar: AppBar(
        title: widget.step.id > 0
            ? Text(tr(context, "edit_step"))
            : Text(tr(context, "new_step")),
        actions: widget.step.id > 0
            ? [
                IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: () async {
                      await widget.crud.delete(widget.step.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(context, "step_deleted"))));
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
                    decoration: InputDecoration(labelText: tr(context, "rank")),
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
                        _updateMap(
                            widget.step.latitude, widget.step.longitude, false);
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
                        _updateMap(
                            widget.step.latitude, widget.step.longitude, false);
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
                    child: Text("Image"),
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
                                InkWell(
                                  onTap: () {
                                    _imgFromCamera();
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: Container(
                                      constraints: BoxConstraints(
                                          maxHeight: 300,
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75),
                                      child: Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                    onPressed: () {
                                      imageBytes = Future.value(null);
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear))
                              ],
                            );
                          } else if (snapshot.hasError) {
                            return Text('${snapshot.error}');
                          }
                          return IconButton(
                              onPressed: () {
                                _imgFromCamera();
                              },
                              icon: const Icon(Icons.camera_alt));
                        },
                      ),
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
                          child: !submitting
                              ? ElevatedButton(
                                  onPressed: () async {
                                    // Validate returns true if the form is valid, or false otherwise.
                                    if (_formKey.currentState!.validate()) {
                                      setState(() {
                                        submitting = true;
                                      });
                                      var msg = tr(context, "step_created");
                                      try {
                                        if (widget.step.id > 0) {
                                          await widget.crud.update(widget.step);
                                          await _imgToServer(widget.step.id);
                                        } else {
                                          var t = await widget.crud
                                              .create(widget.step);
                                          await _imgToServer(t.id);
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
}

String emptyIfZero(num value) {
  return value == 0.0 ? "" : value.toString();
}