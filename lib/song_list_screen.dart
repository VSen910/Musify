import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

class SongListScreen extends StatefulWidget {
  const SongListScreen({Key? key}) : super(key: key);

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  final _audioQuery = OnAudioQuery();
  final _player = AudioPlayer();

  bool _isPlayerScreenVisible = false;

  bool isPlaying = true;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  SongModel? songModel;
  int currentSongIndex = -1;
  List<SongModel>? songs;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  void requestPermission() async {
    await Permission.storage.request();
  }

  Future setAudio() async {
    _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(songModel!.uri!),
        tag: MediaItem(
          // Specify a unique ID for each media item:
          id: '${songModel!.id}',
          // Metadata to display in the notification:
          artist: "${songModel!.artist}",
          title: songModel!.displayNameWOExt,
          artUri: Uri.parse(songModel!.uri!),
        ),
      ),
    );
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return [
      if (duration.inHours > 0) hours,
      minutes,
      seconds,
    ].join(':');
  }

  void _changePlayerScreenVisibility() {
    setState(() {
      _isPlayerScreenVisible = !_isPlayerScreenVisible;
    });
  }

  void onComplete() async {
    setAudio();
    await _player.pause();
  }

  Future<bool> _onWillPop() async {
    _changePlayerScreenVisibility();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlayerScreenVisible) {
      _player.durationStream.listen((newDuration) {
        setState(() {
          duration = newDuration!;
        });
      });

      _player.positionStream.listen((newPosition) {
        setState(() {
          position = newPosition;
        });
      });

      _player.playingStream.listen((event) {
        setState(() {
          isPlaying = event;
        });
      });

      _player.playerStateStream.listen((event) {
        if(_player.processingState == ProcessingState.completed) {
          onComplete();
        }
      });

      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
            ),
            iconTheme: const IconThemeData(
              color: Colors.black,
            ),
            elevation: 0.0,
            backgroundColor: Colors.lightBlue.shade300,
            title: const Text(
              'Now Playing',
              style: TextStyle(color: Colors.black),
            ),
            centerTitle: true,
            leading: BackButton(
              onPressed: () {
                _changePlayerScreenVisibility();
              },
            ),
          ),
          body: Container(
            color: Colors.lightBlue.shade300,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment(0, -0.7),
                      colors: [
                    Colors.black,
                    Color(0x00000000),
                  ])),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Flexible(
                      flex: 5,
                      child: FractionallySizedBox(
                        heightFactor: 0.8,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50.0),
                      child: QueryArtworkWidget(
                        id: songModel!.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 300.0,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: const Icon(
                          Icons.music_note,
                          size: 200.0,
                        ),
                        keepOldArtwork: true,
                      ),
                    ),
                    const Flexible(
                      flex: 6,
                      child: FractionallySizedBox(
                        heightFactor: 0.8,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: Slider.adaptive(
                        activeColor: Colors.white,
                        inactiveColor: Colors.grey,
                        min: 0,
                        max: duration.inSeconds.toDouble(),
                        value: position.inSeconds.toDouble(),
                        onChanged: (val) async {
                          setState(() {
                            position = Duration(seconds: val.toInt());
                          });
                          await _player.seek(position);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 32.0,
                        right: 32.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatTime(position)),
                          Text(formatTime(duration)),
                        ],
                      ),
                    ),
                    const Flexible(
                      flex: 6,
                      child: FractionallySizedBox(
                        heightFactor: 0.8,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            if(currentSongIndex-1>=0) {
                              songModel = songs![currentSongIndex--];
                              setAudio();
                              await _player.play();
                            } else {
                              Fluttertoast.showToast(msg: 'No more songs');
                            }
                          },
                          iconSize: 60.0,
                          splashRadius: 35.0,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(
                          width: 20.0,
                        ),
                        RawMaterialButton(
                          onPressed: () async {
                            if (_player.playing) {
                              await _player.pause();
                            } else {
                              await _player.play();
                            }
                          },
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          fillColor: Colors.white,
                          constraints: const BoxConstraints.tightFor(
                            height: 80.0,
                            width: 80.0,
                          ),
                          child: Icon(
                            _player.playing
                                ? Icons.pause
                                : Icons.play_arrow_rounded,
                            size: 50.0,
                          ),
                        ),
                        const SizedBox(
                          width: 20.0,
                        ),
                        IconButton(
                          onPressed: () async {
                            if(currentSongIndex+1<songs!.length) {
                              songModel = songs![currentSongIndex++];
                              setAudio();
                              await _player.play();
                            } else {
                              Fluttertoast.showToast(msg: 'No more songs');
                            }
                          },
                          iconSize: 60.0,
                          padding: EdgeInsets.zero,
                          splashRadius: 35.0,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Flexible(
                      child: FractionallySizedBox(
                        heightFactor: 1.0,
                      ),
                    ),
                    Text(
                      songModel!.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      songModel!.artist!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade600,
      appBar: AppBar(
        toolbarHeight: 100.0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Musify',
            style: GoogleFonts.playball(
              fontSize: 50.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ),
        elevation: 0.0,
        backgroundColor: Colors.lightBlue.shade600,
        shadowColor: Colors.lightBlue.shade800,
        scrolledUnderElevation: 3.0,
      ),
      body: FutureBuilder(
        future: _audioQuery.querySongs(
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        ),
        builder: (context, item) {
          if (!item.hasData) {
            return const Center(
              child: Text('No songs found'),
            );
          }

          songs = item.data;

          return ListView.builder(
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListTile(
                leading: QueryArtworkWidget(
                  id: item.data![index].id,
                  type: ArtworkType.AUDIO,
                  nullArtworkWidget: const Icon(Icons.music_note),
                  keepOldArtwork: true,
                ),
                tileColor: Colors.lightBlue.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                title: Text(item.data![index].displayNameWOExt),
                subtitle: Text('${item.data![index].artist}'),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                onTap: () async {
                  _changePlayerScreenVisibility();
                  currentSongIndex = index;
                  if(songModel.toString()!=item.data![index].toString()) {
                    songModel = item.data![index];
                    setAudio();
                    await _player.play();
                  }
                },
              ),
            ),
            itemCount: item.data!.length,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
          );
        },
      ),
    );
  }
}
