import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/formatters.dart';
import 'clip_timeline_strip.dart';

/// A quiet overview of the sequence, with one transport for the whole track.
class TimelinePreviewPanel extends StatelessWidget {
  const TimelinePreviewPanel({
    required this.clips,
    required this.total,
    required this.onPreview,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.isPreparing = false,
    this.errorMessage = '',
    this.onReorder,
    super.key,
  });

  final List<TimelineClip> clips;
  final Duration? total;
  final Duration position;
  final bool isPlaying;
  final bool isPreparing;
  final String errorMessage;
  final VoidCallback? onPreview;
  final void Function(int, int)? onReorder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Duration? total = this.total;
    final String elapsed = Formatters.duration(
      isPlaying ? position : Duration.zero,
    );

    return Container(
      key: const ValueKey<String>('timeline-preview-panel'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.view_timeline_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    K.timelineSection.tr,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: total == null || total <= Duration.zero
                ? Text(
                    K.timelineTotalUnknown.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : ClipTimelineStrip(
                    clips: clips,
                    total: total,
                    playhead: isPlaying ? position : null,
                    onReorder: onReorder,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall!.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(elapsed)),
                  Expanded(
                    child: Text(
                      total == null ? '—' : Formatters.duration(total),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget control = FilledButton.tonalIcon(
                  key: const ValueKey<String>('timeline-preview-toggle'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isPreparing ? null : onPreview,
                  icon: isPreparing
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                  label: Text(
                    isPlaying ? K.stop.tr : K.previewTheTrack.tr,
                    textAlign: TextAlign.center,
                  ),
                );
                return SizedBox(width: double.infinity, child: control);
              },
            ),
          ),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}
