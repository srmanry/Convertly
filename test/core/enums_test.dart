import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioFormat', () {
    test('parses a stored name', () {
      expect(AudioFormat.fromName('wav'), AudioFormat.wav);
    });

    test('falls back when the stored name is unknown or missing', () {
      expect(AudioFormat.fromName(null), AudioFormat.mp3);
      expect(AudioFormat.fromName('flac'), AudioFormat.mp3);
      expect(
        AudioFormat.fromName('flac', fallback: AudioFormat.m4a),
        AudioFormat.m4a,
      );
    });

    test('only lossy formats expose a bitrate choice', () {
      expect(AudioFormat.mp3.supportsBitrate, isTrue);
      expect(AudioFormat.m4a.supportsBitrate, isTrue);
      expect(AudioFormat.wav.supportsBitrate, isFalse);
    });

    test('every format declares a file extension', () {
      for (final AudioFormat format in AudioFormat.values) {
        expect(format.extension, isNotEmpty);
        expect(format.extension, isNot(startsWith('.')));
      }
    });
  });

  group('AudioQuality', () {
    test('parses a stored name and falls back safely', () {
      expect(AudioQuality.fromName('kbps320'), AudioQuality.kbps320);
      expect(AudioQuality.fromName(null), AudioQuality.kbps192);
      expect(AudioQuality.fromName('kbps1'), AudioQuality.kbps192);
    });

    test('labels read as kbps values', () {
      expect(AudioQuality.kbps128.label, '128 kbps');
    });

    test('presets are ordered from lowest to highest bitrate', () {
      final List<int> bitrates = AudioQuality.values
          .map((AudioQuality q) => q.bitrate)
          .toList();

      expect(bitrates, orderedEquals(<int>[96, 128, 192, 256, 320]));
    });
  });
}
