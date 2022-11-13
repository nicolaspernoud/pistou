import 'package:pistou/i18n.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPlayer extends StatefulWidget {
  const MediaPlayer({super.key, required this.uri});

  final String uri;

  @override
  State<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<MediaPlayer> {
  late VideoPlayerController _controller;
  Map<String, String> headers = {};

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        httpHeaders: headers);

    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _controller.initialize();
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: SizedBox(
              height: _controller.value.aspectRatio == 1.0 ? 100 : null,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    VideoPlayer(_controller),
                    ClosedCaption(text: _controller.value.caption.text),
                    _ControlsOverlay(controller: _controller),
                    VideoProgressIndicator(
                      padding: const EdgeInsets.only(top: 20.0),
                      _controller,
                      allowScrubbing: true,
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(),
          );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller})
      : super(key: key);

  static const List<double> _playbackRates = <double>[
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    5.0,
    10.0,
  ];

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.blueGrey[100],
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 50.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
        Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<double>(
            initialValue: controller.value.playbackSpeed,
            tooltip: tr(context, "playback_speed"),
            onSelected: (double speed) {
              controller.setPlaybackSpeed(speed);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<double>>[
                for (final double speed in _playbackRates)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              child: Text(
                '${controller.value.playbackSpeed}x',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
