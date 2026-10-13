import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_info.dart';

/// A clip's identity, selection and sequence position in one editing surface.
class TimelineClipCard extends StatelessWidget {
  const TimelineClipCard({
    required this.index,
    required this.media,
    required this.range,
    required this.start,
    required this.onRemove,
    required this.onTrimChanged,
    required this.onPreview,
    this.isPlaying = false,
    this.errorMessage = '',
    super.key,
  });

  final int index;
  final MediaInfo media;
  final (Duration, Duration) range;
  final Duration start;
  final VoidCallback onRemove;
  final void Function(Duration, Duration)? onTrimChanged;
  final VoidCallback? onPreview;
  final bool isPlaying;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = theme.brightness == Brightness.dark
        ? AppColors.mixTrackAccents[index % AppColors.mixTrackAccents.length]
        : Color.lerp(
            AppColors.mixTrackAccents[index % AppColors.mixTrackAccents.length],
            Colors.black,
            0.4,
          )!;
    final Duration length = range.$2 - range.$1;
    final double maxMs = (media.duration ?? Duration.zero).inMilliseconds
        .toDouble();
    final bool canTrim = maxMs > 0 && onTrimChanged != null;
    final bool isTrimmed =
        range.$1 > Duration.zero || range.$2 != media.duration;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPlaying
              ? accent
              : colors.outlineVariant.withValues(alpha: 0.6),
          width: isPlaying ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ReorderableDragStartListener(
                  index: index,
                  // Fill the hit area so padding and gaps also start a drag.
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}'.padLeft(2, '0'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              media.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: K.remove.tr,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          ReorderableDelayedDragStartListener(
            index: index,
            child: ColoredBox(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (canTrim)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accent,
                              inactiveTrackColor: accent.withValues(
                                alpha: 0.15,
                              ),
                              thumbColor: accent,
                              overlayColor: accent.withValues(alpha: 0.12),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              trackHeight: 2,
                              rangeThumbShape: const RoundRangeSliderThumbShape(
                                enabledThumbRadius: 7,
                                disabledThumbRadius: 7,
                              ),
                              showValueIndicator: ShowValueIndicator.onDrag,
                            ),
                            child: RangeSlider(
                              max: maxMs,
                              values: RangeValues(
                                range.$1.inMilliseconds.toDouble().clamp(
                                  0,
                                  maxMs,
                                ),
                                range.$2.inMilliseconds.toDouble().clamp(
                                  range.$1.inMilliseconds.toDouble().clamp(
                                    0,
                                    maxMs,
                                  ),
                                  maxMs,
                                ),
                              ),
                              labels: RangeLabels(
                                Formatters.duration(range.$1),
                                Formatters.duration(range.$2),
                              ),
                              semanticFormatterCallback: (double value) =>
                                  Formatters.duration(
                                    Duration(milliseconds: value.round()),
                                  ),
                              onChanged: (RangeValues values) => onTrimChanged!(
                                Duration(milliseconds: values.start.round()),
                                Duration(milliseconds: values.end.round()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: <Widget>[
                              Text(
                                media.duration == null
                                    ? K.startsAt.trParams(<String, String>{
                                        'time': Formatters.duration(start),
                                      })
                                    : '${K.playsAt.trParams(<String, String>{'time': Formatters.duration(start)})} – ${Formatters.duration(start + length)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (canTrim)
                                Text(
                                  Formatters.duration(length),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (canTrim && isTrimmed)
                          IconButton(
                            tooltip: K.reset.tr,
                            onPressed: () =>
                                onTrimChanged!(Duration.zero, media.duration!),
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 22,
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: isPlaying ? K.stop.tr : K.play.tr,
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(36),
                            minimumSize: const Size.square(36),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.padded,
                            backgroundColor: accent.withValues(alpha: 0.14),
                            foregroundColor: accent,
                            shape: const CircleBorder(),
                          ),
                          onPressed: onPreview,
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        errorMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
