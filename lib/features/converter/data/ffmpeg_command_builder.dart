import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/export_speed.dart';
import '../../../../core/enums/noise_strength.dart';
import '../domain/entities/cleanup_settings.dart';
import '../domain/entities/conversion_request.dart';
import '../domain/entities/mix_settings.dart';
import '../domain/entities/mix_track.dart';

/// Translates a [ConversionRequest] into FFmpeg arguments.
///
/// Pure logic with no plugin calls, so the command for every tool can be
/// verified in unit tests rather than only on a device.
abstract final class FfmpegCommandBuilder {
  /// Encoder for each output format.
  static String codecFor(AudioFormat format) => switch (format) {
    AudioFormat.mp3 => 'libmp3lame',
    AudioFormat.m4a => 'aac',
    // WAV is uncompressed PCM, which is why it takes no bitrate.
    AudioFormat.wav => 'pcm_s16le',
  };

  static List<String> build(ConversionRequest request) {
    return <String>[
      // Overwrite without prompting; output paths are already collision-free.
      '-y',
      '-hide_banner',
      ..._inputArguments(request),
      if (request.isMix)
        ..._mixArguments(request)
      else if (request.isMerge)
        ..._mergeArguments(request)
      else
        ..._singleInputArguments(request),
      ..._encoderArguments(request),
      request.outputPath,
    ];
  }

  /// The inputs, each with whatever has to be set before it is opened.
  static List<String> _inputArguments(ConversionRequest request) {
    final MixSettings? mix = request.mix;

    return <String>[
      for (int index = 0; index < request.inputPaths.length; index++) ...[
        // -stream_loop is an input option, so it belongs before its own -i.
        // An endless layer is safe because a looping mix always ends with the
        // main track; see MixSettings.effectiveLengthMode.
        if (mix != null && mix.loopsTrack(index)) ...<String>[
          '-stream_loop',
          '-1',
        ],
        '-i',
        request.inputPaths[index],
      ],
    ];
  }

  /// Trimming, cleanup and video stripping for a single-input conversion.
  static List<String> _singleInputArguments(ConversionRequest request) {
    final List<String> filters = <String>[
      if (request.cleanup case final CleanupSettings cleanup)
        ..._cleanupFilters(cleanup),
      if (!request.speed.isNormal) _tempoFilter(request.speed),
    ];

    return <String>[
      // Placed after -i so the seek is frame-accurate rather than approximate.
      if (request.trimStart case final Duration start) ...<String>[
        '-ss',
        _seconds(start),
      ],
      if (request.trimEnd case final Duration end) ...<String>[
        '-to',
        _seconds(end),
      ],
      // Drop any video stream: every output format here is audio-only.
      '-vn',
      if (filters.isNotEmpty) ...<String>['-filter:a', filters.join(',')],
    ];
  }

  /// Concatenation filter for a merge.
  ///
  /// The filter re-encodes, which is what allows inputs with different sample
  /// rates or codecs to be joined without producing a corrupt file.
  static List<String> _mergeArguments(ConversionRequest request) {
    final int count = request.inputPaths.length;
    final String inputs = List<String>.generate(
      count,
      (int index) => '[$index:a]',
    ).join();

    // A tempo change becomes a second stage in the same filter graph, since
    // -filter:a cannot be combined with -filter_complex.
    final String graph = request.speed.isNormal
        ? '${inputs}concat=n=$count:v=0:a=1[out]'
        : '${inputs}concat=n=$count:v=0:a=1[joined];'
              '[joined]${_tempoFilter(request.speed)}[out]';

    return <String>['-filter_complex', graph, '-map', '[out]'];
  }

  /// Filter that places every input on one timeline and sums them.
  ///
  /// Unlike a merge, which plays the inputs strictly in sequence, each input
  /// here starts at its own point. Tracks left at zero sound together; tracks
  /// with increasing starts play one after another, with silence across the
  /// gaps. Both come out of the same graph, which is why one tool covers
  /// layering a background under a song and arranging clips along a timeline.
  static List<String> _mixArguments(ConversionRequest request) {
    final MixSettings mix = request.mix!;
    final int count = request.inputPaths.length;
    final StringBuffer graph = StringBuffer();

    // Each clip is cut to the part being used, moved to where it plays, and
    // levelled, all before the sum. Cutting first is what makes the position
    // mean the same thing for a trimmed clip as for a whole one.
    for (int index = 0; index < count; index++) {
      final MixTrack clip = mix.trackAt(index);
      graph.write('[$index:a]');
      for (final String filter in _clipFilters(clip)) {
        graph.write('$filter,');
      }
      graph.write('volume=${_gain(clip.volume)}[t$index];');
    }
    for (int index = 0; index < count; index++) {
      graph.write('[t$index]');
    }

    // normalize=0 keeps the chosen volumes literal instead of scaling them
    // down by the input count, so a quiet layer stays a quiet layer. Summing
    // at full level can then exceed full scale, which is what the limiter
    // afterwards is for; without it the overshoot would clip audibly.
    graph.write(
      'amix=inputs=$count'
      ':duration=${mix.effectiveLengthMode.ffmpegDuration}'
      ':dropout_transition=0'
      ':normalize=0[mixed];',
    );
    graph.write('[mixed]$_mixLimiter');
    if (!request.speed.isNormal) {
      graph.write(',${_tempoFilter(request.speed)}');
    }
    graph.write('[out]');

    return <String>['-filter_complex', graph.toString(), '-map', '[out]'];
  }

  /// Cuts [clip] down to the part being used and moves it to where it plays.
  ///
  /// A clip that is neither trimmed nor moved produces nothing, so an
  /// untouched graph carries no no-op filters.
  static List<String> _clipFilters(MixTrack clip) {
    return <String>[
      if (clip.isTrimmed) ..._trimFilters(clip),
      // `all=1` delays every channel, which avoids having to know the channel
      // count in order to write one delay per channel.
      if (clip.start > Duration.zero)
        'adelay=${clip.start.inMilliseconds}:all=1',
    ];
  }

  /// Keeps only the selected part of a clip.
  ///
  /// `atrim` leaves the kept audio carrying its original timestamps, so it
  /// would still play at the point it sat in the source. `asetpts` rebases it
  /// to zero; without that, any delay after it would be measured from the
  /// wrong place.
  static List<String> _trimFilters(MixTrack clip) {
    return <String>[
      <String>[
        'atrim=start=${_seconds(clip.trimStart)}',
        if (clip.trimEnd case final Duration end) 'end=${_seconds(end)}',
      ].join(':'),
      'asetpts=PTS-STARTPTS',
    ];
  }

  /// Catches the peaks that summing tracks produces.
  ///
  /// `level=0` disables the filter's own auto-gain, which would otherwise
  /// push every mix back up to full scale and undo the volumes above.
  static const String _mixLimiter = 'alimiter=limit=0.95:level=0';

  /// Filter chain for the noise remover.
  ///
  /// These are signal filters, not source separation: they subtract a measured
  /// noise profile or cancel what both channels share. A model-based split
  /// into vocals and instruments is not something FFmpeg can do offline.
  static List<String> _cleanupFilters(CleanupSettings cleanup) {
    return switch (cleanup.mode) {
      // Below 80 Hz is rumble and handling noise rather than signal, so it is
      // cut before the denoiser measures anything.
      CleanupMode.backgroundNoise => <String>[
        'highpass=f=80',
        _denoiseFilter(cleanup.strength),
      ],
      // Speech lives roughly between these two, so everything outside the band
      // goes before what is left is denoised.
      CleanupMode.voiceFocus => <String>[
        'highpass=f=200',
        'lowpass=f=3400',
        _denoiseFilter(cleanup.strength),
      ],
      // Lead vocals are mixed to the centre, so subtracting each channel from
      // the other cancels them. Anything panned to a side survives.
      CleanupMode.removeVocals => const <String>[
        'pan=stereo|c0=c0-c1|c1=c1-c0',
      ],
    };
  }

  /// Adaptive denoiser. It profiles the noise from the audio itself, which is
  /// what `tn=1` turns on, rather than assuming a fixed noise shape.
  static String _denoiseFilter(NoiseStrength strength) =>
      'afftdn=nr=${strength.reductionDb}:nf=${strength.floorDb}:tn=1';

  /// Tempo change that preserves pitch.
  ///
  /// `atempo` only accepts 0.5 to 2.0 per instance; every speed offered is
  /// inside that range, so one filter is always enough.
  static String _tempoFilter(ExportSpeed speed) => 'atempo=${speed.value}';

  static List<String> _encoderArguments(ConversionRequest request) {
    return <String>[
      '-c:a',
      codecFor(request.format),
      if (request.format.supportsBitrate &&
          request.quality != null) ...<String>[
        '-b:a',
        '${request.quality!.bitrate}k',
      ],
    ];
  }

  /// A `volume` multiplier, trimmed so a whole number reads as `1` not `1.00`.
  static String _gain(double value) {
    final String text = value.toStringAsFixed(2);
    return text.endsWith('.00') ? value.round().toString() : text;
  }

  /// FFmpeg accepts a plain seconds value with millisecond precision.
  static String _seconds(Duration duration) {
    return (duration.inMilliseconds / 1000).toStringAsFixed(3);
  }
}
