import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/i18n/translation_keys.dart';
import 'option_chips.dart';

class TimelineExportOptions extends StatelessWidget {
  const TimelineExportOptions({
    required this.formats,
    required this.format,
    required this.quality,
    required this.onFormatChanged,
    required this.onQualityChanged,
    super.key,
  });

  final List<AudioFormat> formats;
  final AudioFormat format;
  final AudioQuality quality;
  final ValueChanged<AudioFormat> onFormatChanged;
  final ValueChanged<AudioQuality> onQualityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OptionChips<AudioFormat>(
          title: K.outputFormatSection.tr,
          options: formats,
          selected: format,
          labelBuilder: (value) => value.label,
          onSelected: onFormatChanged,
        ),
        if (format.supportsBitrate) ...<Widget>[
          const SizedBox(height: 20),
          OptionChips<AudioQuality>(
            title: K.qualitySection.tr,
            options: AudioQuality.values,
            selected: quality,
            labelBuilder: (value) => value.label,
            onSelected: onQualityChanged,
          ),
        ],
      ],
    );
  }
}
