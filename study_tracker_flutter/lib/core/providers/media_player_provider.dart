import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import '../../data/repositories/settings_repository.dart';

class MediaTrack {
  final String path;
  final String title;

  const MediaTrack({
    required this.path,
    required this.title,
  });
}

enum FloatingMediaBarState { hidden, minimized, expanded }

class MediaPlayerProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  final AudioPlayer _player = AudioPlayer();

  List<MediaTrack> tracks = const [];
  String? libraryFolderPath;
  bool isScanning = false;
  FloatingMediaBarState floatingBarState = FloatingMediaBarState.minimized;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  MediaPlayerProvider(this._settingsRepo) {
    _init();
  }

  AudioPlayer get player => _player;

  int? get currentIndex => _player.currentIndex;

  MediaTrack? get currentTrack {
    final index = currentIndex;
    if (index == null || index < 0 || index >= tracks.length) return null;
    return tracks[index];
  }

  bool get isPlaying => _player.playing;

  bool get hasLoadedLibrary => tracks.isNotEmpty;

  void setFloatingBarState(FloatingMediaBarState state) {
    if (floatingBarState == state) return;
    floatingBarState = state;
    notifyListeners();
  }

  void toggleFloatingBarExpanded() {
    floatingBarState = floatingBarState == FloatingMediaBarState.expanded
        ? FloatingMediaBarState.minimized
        : FloatingMediaBarState.expanded;
    notifyListeners();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _playerStateSub = _player.playerStateStream.listen((_) {
      notifyListeners();
    });
    _indexSub = _player.currentIndexStream.listen((_) {
      notifyListeners();
    });
    _positionSub = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 500),
          maxPeriod: const Duration(seconds: 1),
        )
        .listen((value) {
      position = value;
      notifyListeners();
    });
    _durationSub = _player.durationStream.listen((value) {
      duration = value ?? Duration.zero;
      notifyListeners();
    });

    // Avoid recursive folder scans during app startup; users now add files explicitly.
    final saved = await _settingsRepo.get('focusAudioFolderPath');
    if (saved != null && saved.trim().isNotEmpty) {
      libraryFolderPath = saved.trim();
      notifyListeners();
    }
  }

  Future<void> pickAndLoadFolder() async {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    final wasPlaying = isPlaying;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac'],
      );

      if (result == null || result.files.isEmpty) return;

      final newTracks = result.files
          .where((f) => f.path != null)
          .map((f) => MediaTrack(
                path: f.path!,
                title: f.name,
              ))
          .toList();

      tracks = newTracks;
      libraryFolderPath = null; // No longer bound to a folder

      if (tracks.isNotEmpty) {
        await _loadPlaylist(initialIndex: 0);
        floatingBarState = FloatingMediaBarState.minimized;
        if (wasPlaying) {
          await _player.play();
        }
        notifyListeners();
      }
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _loadPlaylist({int? initialIndex}) async {
    if (tracks.isEmpty) {
      await _player.stop();
      duration = Duration.zero;
      return;
    }

    final current = _player.currentIndex;
    final targetIndex = initialIndex ?? current ?? 0;
    final safeIndex = (targetIndex >= 0 && targetIndex < tracks.length) ? targetIndex : 0;

    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: tracks.map((track) {
        return AudioSource.uri(
          Uri.file(track.path),
          tag: MediaItem(
            id: track.path,
            title: track.title,
            artist: 'Focus Audio',
            album: 'Local Library',
          ),
        );
      }).toList(growable: false),
    );

    await _player.setAudioSource(
      playlist,
      initialIndex: safeIndex,
      preload: false,
    );
    duration = _player.duration ?? Duration.zero;
  }

  // loadFolder remains for possible background loading from settings if needed
  Future<void> loadFolder(String folderPath, {bool persist = true}) async {
    isScanning = true;
    notifyListeners();

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        tracks = const [];
        libraryFolderPath = null;
        await _player.stop();
        return;
      }

      const allowed = <String>{
        '.mp3',
        '.wav',
        '.m4a',
        '.aac',
        '.ogg',
        '.flac',
      };

      final discovered = <String>[];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!allowed.contains(ext)) continue;
        discovered.add(entity.path);
      }

      discovered.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      tracks = discovered
          .map(
            (path) => MediaTrack(
              path: path,
              title: p.basenameWithoutExtension(path),
            ),
          )
          .toList(growable: false);

      libraryFolderPath = folderPath;
      if (persist) {
        await _settingsRepo.set('focusAudioFolderPath', folderPath);
      }

      if (tracks.isEmpty) {
        await _player.stop();
        return;
      }

      final previousIndex = _player.currentIndex;
      await _loadPlaylist(initialIndex: previousIndex);
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= tracks.length) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _player.pause();
    } else {
      if (tracks.isEmpty) return;
      if (_player.currentIndex == null) {
        await playAt(0);
      } else {
        await _player.play();
      }
    }
  }

  Future<void> seek(Duration to) async {
    await _player.seek(to);
  }

  Future<void> rewind10s() async {
    final target = position - const Duration(seconds: 10);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> skipForward10s() async {
    final max = duration;
    final target = position + const Duration(seconds: 10);
    await _player.seek(target > max ? max : target);
  }

  Future<void> nextTrack() async {
    await _player.seekToNext();
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> previousTrack() async {
    await _player.seekToPrevious();
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    position = Duration.zero;
    duration = Duration.zero;
    floatingBarState = FloatingMediaBarState.hidden;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _indexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final mediaPlayerProvider = ChangeNotifierProvider<MediaPlayerProvider>((ref) {
  return MediaPlayerProvider(ref.watch(settingsRepositoryProvider));
});
