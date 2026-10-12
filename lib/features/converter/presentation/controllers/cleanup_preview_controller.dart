import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/services/ffmpeg_service.dart';
import '../../../../core/services/output_directory_service.dart';
import '../../../../core/utils/playable_audio_source.dart';
import '../../data/ffmpeg_command_builder.dart';
import '../../domain/entities/cleanup_settings.dart';
import '../../domain/entities/conversion_request.dart';

/// Tags the two things the cleanup screen can play.
abstract final class CleanupPreviewTag {
  static const String original = 'original';
  static const String cleaned = 'cleaned';
}

/// Plays a short sample of a track, before and after the clean-up.
///
/// Denoising cannot be heard while it is being set up: the filters run inside
/// FFmpeg, not in the player. So the cleaned side is rendered to a small file
/// first and that is what plays. The original side needs no rendering, which
/// is what makes the two worth putting side by side.
class CleanupPreviewController extends GetxController {
  CleanupPreviewController(this._ffmpeg, this._directories);

  /// How much of the track is rendered and played.
  ///
  /// Long enough to judge the result, short enough that the wait before it
  /// starts is not itself the thing being judged.
  static const Duration sampleLength = Duration(seconds: 15);

  /// Its own engine instance rather than the shared one: the preview runs
  /// while the user is still choosing settings, and cancelling a conversion
  /// must not reach in and stop it, nor the other way round.
  final FfmpegService _ffmpeg;
  final OutputDirectoryService _directories;

  final AudioPlayer _player = AudioPlayer();

  final RxBool isPlaying = false.obs;

  /// True only while the cleaned sample is being rendered, which is the one
  /// wait the user sees on this screen.
  final RxBool isRendering = false.obs;

  /// Which side is playing, or empty. See [CleanupPreviewTag].
  final RxString playingTag = ''.obs;
  final RxString errorMessage = ''.obs;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// Source currently loaded, so replaying the same side does not reload it.
  String? _loadedSource;

  /// What the rendered sample was made from, so settings that have not
  /// changed do not pay to render it a second time.
  String? _renderedKey;
  String? _renderedPath;

  @override
  void onInit() {
    super.onInit();
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.playerStateStream.listen((PlayerState state) {
        isPlaying.value = state.playing;
        if (state.processingState == ProcessingState.completed) {
          unawaited(stop());
        }
      }),
    ]);
  }

  /// Plays the first [sampleLength] of [source] untouched.
  Future<void> toggleOriginal(String source) async {
    if (await _handledAsPauseOrResume(CleanupPreviewTag.original)) {
      return;
    }
    await _play(source, tag: CleanupPreviewTag.original, clip: true);
  }

  /// Renders the first [sampleLength] of [source] through [cleanup], then
  /// plays it.
  ///
  /// The render is skipped when the same settings were rendered before and
  /// the file is still there.
  Future<void> toggleCleaned({
    required String source,
    required CleanupSettings cleanup,
  }) async {
    if (await _handledAsPauseOrResume(CleanupPreviewTag.cleaned)) {
      return;
    }

    final String key = '$source|${cleanup.props.join('|')}';
    String? rendered = _renderedKey == key ? _renderedPath : null;
    if (rendered != null && !File(rendered).existsSync()) {
      rendered = null;
    }

    if (rendered == null) {
      isRendering.value = true;
      errorMessage.value = '';
      try {
        rendered = await _render(source: source, cleanup: cleanup);
      } finally {
        isRendering.value = false;
      }
      if (rendered == null) {
        errorMessage.value = K.previewFailed.tr;
        return;
      }
      _renderedKey = key;
      _renderedPath = rendered;
    }

    await _play(rendered, tag: CleanupPreviewTag.cleaned, clip: false);
  }

  /// Runs the clean-up over the sample, returning where it landed.
  ///
  /// Rendered as WAV: it encodes fastest, and nothing here is kept.
  Future<String?> _render({
    required String source,
    required CleanupSettings cleanup,
  }) async {
    try {
      final Directory directory = await _directories.resolveTemp();
      // One fixed name, overwritten each time, so previews cannot pile up in
      // the cache over a long session.
      final String path = '${directory.path}/cleanup_preview.wav';

      final FfmpegRunResult result = await _ffmpeg.run(
        arguments: FfmpegCommandBuilder.build(
          ConversionRequest(
            inputPaths: <String>[source],
            outputPath: path,
            format: AudioFormat.wav,
            trimStart: Duration.zero,
            trimEnd: sampleLength,
            cleanup: cleanup,
          ),
        ),
      );

      return result.isSuccess ? path : null;
    } on Exception {
      return null;
    }
  }

  /// Handles a tap on the side that is already loaded.
  ///
  /// Returns true when the tap was a pause or a resume and nothing further
  /// should happen. The button shows a pause symbol while it plays, so it has
  /// to pause where it is rather than start the sample over; tapping the
  /// other side stops this one and loads that one instead.
  Future<bool> _handledAsPauseOrResume(String tag) async {
    if (playingTag.value != tag) {
      if (playingTag.value.isNotEmpty) {
        await stop();
      }
      return false;
    }

    if (isPlaying.value) {
      await _player.pause();
      isPlaying.value = false;
    } else {
      unawaited(_player.play().catchError((Object _) {}));
    }
    return true;
  }

  Future<void> _play(
    String source, {
    required String tag,
    required bool clip,
  }) async {
    errorMessage.value = '';
    try {
      if (_loadedSource != source) {
        await _player.setAudioSource(playableAudioSource(source));
        _loadedSource = source;
      }
      // The rendered sample is already the right length; the original is not,
      // so it is bounded here rather than cut to a file first.
      await _player.setClip(
        start: clip ? Duration.zero : null,
        end: clip ? sampleLength : null,
      );
      await _player.seek(Duration.zero);
      playingTag.value = tag;
      // Not awaited: play() completes when playback ends, not when it starts,
      // so awaiting it would hold the button in its busy state throughout.
      unawaited(
        _player.play().catchError((Object _) {
          errorMessage.value = K.previewFailed.tr;
          playingTag.value = '';
        }),
      );
    } catch (error) {
      _loadedSource = null;
      errorMessage.value = K.previewFailed.tr;
      playingTag.value = '';
    }
  }

  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    isPlaying.value = false;
    playingTag.value = '';
  }

  @override
  void onClose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player.dispose();
    super.onClose();
  }
}
