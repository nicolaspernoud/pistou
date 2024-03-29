import 'package:just_audio/just_audio.dart';
import 'package:pistou/i18n.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPlayer extends StatefulWidget {
  const MediaPlayer({super.key, required this.uri, required this.autoplay});

  final String uri;
  final bool autoplay;

  @override
  State<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<MediaPlayer> {
  VideoPlayerController? videoController;
  bool audioOnly = false;
  Map<String, String> headers = {};
  AudioPlayer? audioPlayer;

  @override
  void initState() {
    super.initState();
    if (widget.uri.endsWith("mp3") || widget.uri.endsWith("wav")) {
      // This is a sound
      audioOnly = true;
      audioPlayer = AudioPlayer(); // Create a player
      audioPlayer?.setUrl(// Load a URL
          widget.uri).then((value) {
        if (widget.autoplay) {
          audioPlayer?.play();
          setState(() {});
        }
      });
    } else {
      // If not, this is a video
      videoController = VideoPlayerController.networkUrl(
          Uri.parse(
              "${widget.uri}?date=${DateTime.now().millisecondsSinceEpoch}"),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          httpHeaders: headers);

      videoController?.addListener(() {
        setState(() {});
      });
      videoController?.setLooping(true);
      videoController?.initialize();
      if (widget.autoplay) videoController?.play();
    }
  }

  @override
  void dispose() {
    if (audioPlayer != null) audioPlayer!.dispose();
    if (videoController != null) videoController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (audioOnly) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          Padding(
              padding: const EdgeInsets.all(40),
              child: audioPlayer!.playing
                  ? IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: () async {
                        await audioPlayer?.stop();
                        setState(() {});
                      })
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        audioPlayer?.play();
                        setState(() {});
                      })),
          _AudioControlsOverlay(audioPlayer: audioPlayer!),
        ],
      );
    } else {
      return videoController!.value.isInitialized
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: SizedBox(
                height: videoController?.value.aspectRatio == 1.0 ? 100 : null,
                child: AspectRatio(
                  aspectRatio: videoController!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      VideoPlayer(videoController!),
                      ClosedCaption(text: videoController?.value.caption.text),
                      _ControlsOverlay(controller: videoController!),
                      VideoProgressIndicator(
                        padding: const EdgeInsets.only(top: 20.0),
                        videoController!,
                        allowScrubbing: true,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
  }
}

const List<double> _playbackRates = <double>[
  0.25,
  0.5,
  1.0,
  1.5,
  2.0,
  3.0,
  5.0,
  10.0,
];

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

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
            child:
                PlaybackSpeedIndicator(value: controller.value.playbackSpeed),
          ),
        ),
      ],
    );
  }
}

class PlaybackSpeedIndicator extends StatelessWidget {
  const PlaybackSpeedIndicator({
    super.key,
    required this.value,
  });

  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 16,
      ),
      child: Text(
        '${value}x',
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
    );
  }
}

class _AudioControlsOverlay extends StatefulWidget {
  const _AudioControlsOverlay({required this.audioPlayer});

  final AudioPlayer audioPlayer;

  @override
  State<_AudioControlsOverlay> createState() => _AudioControlsOverlayState();
}

class _AudioControlsOverlayState extends State<_AudioControlsOverlay> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
        initialValue: widget.audioPlayer.speed,
        tooltip: tr(context, "playback_speed"),
        onSelected: (double speed) {
          setState(() {
            widget.audioPlayer.setSpeed(speed);
          });
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
        child: PlaybackSpeedIndicator(value: widget.audioPlayer.speed));
  }
}
