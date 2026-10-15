import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/formatters.dart';
import 'mix_preview_waveform.dart';

/// Progress and a single preview control for the whole mix.
class MixPreviewPanel extends StatefulWidget {
  const MixPreviewPanel({
    required this.onPreview,
    required this.total,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.isPreparing = false,
    this.errorMessage = '',
    super.key,
  });

  final VoidCallback? onPreview;
  final Duration? total;
  final Duration position;
  final bool isPlaying;
  final bool isPreparing;
  final String errorMessage;

  // Keep the original widget/state types stable across design hot reloads.
  @override
  State<MixPreviewPanel> createState() => _MixPreviewPanelState();
}

class _MixPreviewPanelState extends State<MixPreviewPanel> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final bool playing = widget.isPlaying && !widget.isPreparing;
    final bool enabled = widget.onPreview != null;
    final Color buttonFill = dark
        ? Color.lerp(colors.primary, Colors.white, 0.48)!
        : colors.primaryContainer;
    final Color buttonInk = enabled
        ? (dark ? colors.onPrimary : colors.onPrimaryContainer)
        : colors.onSurface.withValues(alpha: 0.38);
    final Duration elapsed = playing ? widget.position : Duration.zero;
    final Duration? total = widget.total;
    final double fraction = total == null || total <= Duration.zero
        ? 0
        : (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final String action = playing ? K.stop.tr : K.preview.tr;

    return AnimatedContainer(
      key: const ValueKey<String>('mix-preview-panel'),
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceContainerLow,
        border: Border.all(
          color: colors.onSurface.withValues(alpha: dark ? 0.09 : 0.07),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: dark ? 0.18 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MixPreviewWaveform(isPlaying: playing),
          const SizedBox(height: 12),
          if (total != null && total > Duration.zero)
            Semantics(
              label: K.previewAll.tr,
              value:
                  '${Formatters.duration(elapsed)} / ${Formatters.duration(total)}',
              child: ExcludeSemantics(
                child: Row(
                  key: const ValueKey<String>('mix-preview-progress'),
                  children: <Widget>[
                    _TimeLabel(time: elapsed, highlighted: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            LinearProgressIndicator(
                              value: fraction,
                              minHeight: 3,
                              stopIndicatorRadius: 0,
                              borderRadius: BorderRadius.circular(4),
                              color: colors.primary,
                              backgroundColor: colors.onSurface.withValues(
                                alpha: 0.10,
                              ),
                            ),
                            AnimatedAlign(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              alignment: AlignmentDirectional(
                                fraction * 2 - 1,
                                0,
                              ),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: playing ? buttonFill : colors.primary,
                                  boxShadow: playing
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: colors.primary.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _TimeLabel(time: total),
                  ],
                ),
              ),
            ),
          if (widget.errorMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                widget.errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Tooltip(
            message: action,
            child: FilledButton(
              key: const ValueKey<String>('mix-preview-toggle'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: buttonFill,
                // Loading blocks duplicate taps without changing the fill.
                disabledBackgroundColor: enabled
                    ? buttonFill
                    : colors.onSurface.withValues(alpha: 0.06),
                disabledForegroundColor: buttonInk,
                foregroundColor: buttonInk,
                overlayColor: colors.primary.withValues(alpha: 0.06),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: widget.isPreparing ? null : widget.onPreview,
              child: widget.isPreparing
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: buttonInk,
                        semanticsLabel: action,
                      ),
                    )
                  : Text(action, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.time, this.highlighted = false});

  final Duration time;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Text(
      Formatters.duration(time),
      style: theme.textTheme.labelSmall?.copyWith(
        color: highlighted ? colors.primary : colors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
