import '../../../../core/enums/audio_format.dart';
import '../domain/entities/conversion_request.dart';

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
      for (final String input in request.inputPaths) ...<String>['-i', input],
      ...request.isMerge
          ? _mergeArguments(request)
          : _singleInputArguments(request),
      ..._encoderArguments(request),
      request.outputPath,
    ];
  }

  /// Trimming and video stripping for a single-input conversion.
  static List<String> _singleInputArguments(ConversionRequest request) {
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

    return <String>[
      '-filter_complex',
      '${inputs}concat=n=$count:v=0:a=1[out]',
      '-map',
      '[out]',
    ];
  }

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

  /// FFmpeg accepts a plain seconds value with millisecond precision.
  static String _seconds(Duration duration) {
    return (duration.inMilliseconds / 1000).toStringAsFixed(3);
  }
}
