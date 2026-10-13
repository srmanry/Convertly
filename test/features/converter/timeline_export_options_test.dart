import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/presentation/widgets/timeline_export_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('format and quality choices update and WAV hides bitrate', (
    tester,
  ) async {
    AudioFormat format = AudioFormat.mp3;
    AudioQuality quality = AudioQuality.kbps128;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TimelineExportOptions(
              formats: AudioFormat.values,
              format: format,
              quality: quality,
              onFormatChanged: (value) => setState(() => format = value),
              onQualityChanged: (value) => setState(() => quality = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('320 kbps'));
    await tester.pump();
    expect(quality, AudioQuality.kbps320);
    await tester.tap(find.text('WAV'));
    await tester.pump();
    expect(format, AudioFormat.wav);
    expect(find.text('320 kbps'), findsNothing);
    await tester.tap(find.text('MP3'));
    await tester.pump();
    expect(find.text('320 kbps'), findsOneWidget);
    expect(quality, AudioQuality.kbps320);
  });

  testWidgets('options fit narrow screens with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TimelineExportOptions(
                formats: AudioFormat.values,
                format: AudioFormat.mp3,
                quality: AudioQuality.kbps128,
                onFormatChanged: (_) {},
                onQualityChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
