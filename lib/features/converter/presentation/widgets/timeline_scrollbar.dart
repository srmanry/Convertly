import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';

/// Explicit navigation for a timeline whose waveform does not swipe-scroll.
class TimelineScrollbar extends StatefulWidget {
  const TimelineScrollbar({
    required this.controller,
    required this.viewportExtent,
    required this.contentExtent,
    super.key,
  });

  static const ValueKey<String> railKey = ValueKey<String>(
    'timeline-scroll-rail',
  );
  static const ValueKey<String> thumbKey = ValueKey<String>(
    'timeline-scroll-thumb',
  );
  final ScrollController controller;
  final double viewportExtent;
  final double contentExtent;

  @override
  State<TimelineScrollbar> createState() => _TimelineScrollbarState();
}

class _TimelineScrollbarState extends State<TimelineScrollbar> {
  double _startX = 0;
  double _startOffset = 0;

  void _scrollTo(double offset) {
    if (!widget.controller.hasClients) return;
    // Reparenting during hot reload can briefly leave the old view attached.
    // Navigate only the newest position after it has completed layout.
    final ScrollPosition position = widget.controller.positions.last;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final double maxScroll = math.max(
          0,
          widget.contentExtent - widget.viewportExtent,
        );
        final ScrollPosition? position = widget.controller.positions.lastOrNull;
        final double offset = position != null && position.hasPixels
            ? position.pixels
            : 0;
        final bool canScroll = maxScroll > 0;
        final double step = widget.viewportExtent * 0.7;
        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            // A compact grip controls the scroll position instead of
            // filling almost the entire rail for short timelines.
            final double thumbWidth = math.min(width, 14);
            final double travel = width - thumbWidth;
            final double left = maxScroll <= 0
                ? travel / 2
                : (offset / maxScroll).clamp(0.0, 1.0) * travel;
            void move(double x) {
              if (travel <= 0) return;
              _scrollTo(_startOffset + (x - _startX) / travel * maxScroll);
            }

            return Semantics(
              label: K.timelineScrollLabel.tr,
              value:
                  '${maxScroll <= 0 ? 0 : (offset / maxScroll * 100).round()}%',
              increasedValue: canScroll
                  ? '${((offset + step).clamp(0.0, maxScroll) / maxScroll * 100).round()}%'
                  : null,
              decreasedValue: canScroll
                  ? '${((offset - step).clamp(0.0, maxScroll) / maxScroll * 100).round()}%'
                  : null,
              onIncrease: canScroll ? () => _scrollTo(offset + step) : null,
              onDecrease: canScroll ? () => _scrollTo(offset - step) : null,
              child: MouseRegion(
                cursor: canScroll
                    ? SystemMouseCursors.grab
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  key: TimelineScrollbar.railKey,
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: canScroll
                      ? (details) {
                          _startX = details.localPosition.dx;
                          _startOffset = offset;
                        }
                      : null,
                  onHorizontalDragStart: canScroll
                      ? (details) => move(details.localPosition.dx)
                      : null,
                  onHorizontalDragUpdate: canScroll
                      ? (details) => move(details.localPosition.dx)
                      : null,
                  onTapUp: canScroll
                      ? (details) {
                          if (travel > 0 &&
                              (details.localPosition.dx < left ||
                                  details.localPosition.dx >
                                      left + thumbWidth)) {
                            _scrollTo(
                              (details.localPosition.dx - thumbWidth / 2) /
                                  travel *
                                  maxScroll,
                            );
                          }
                        }
                      : null,
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Positioned(
                          left: left,
                          width: thumbWidth,
                          height: 14,
                          child: Container(
                            key: TimelineScrollbar.thumbKey,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: canScroll
                                  ? colors.primary
                                  : colors.outlineVariant,
                              shape: BoxShape.circle,
                              boxShadow: canScroll
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: colors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 4,
                                        offset: Offset.zero,
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
              ),
            );
          },
        );
      },
    );
  }
}
