import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/compression_level.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/entities/media_info.dart';
import '../controllers/converter_controller.dart';
import '../widgets/option_chips.dart';
import '../widgets/source_summary_card.dart';
import 'conversion_progress_view.dart';

/// Configuration screen shared by every conversion tool.
class ConverterPage extends GetView<ConverterController> {
  const ConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.mode.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Obx(() {
              return switch (controller.stage.value) {
                ConverterStage.converting => const ConversionProgressView(),
                ConverterStage.failed => _FailureView(controller: controller),
                _ => _ConfigurationView(controller: controller),
              };
            }),
          ),
        ),
      ),
    );
  }
}

/// Shown when FFmpeg could not produce an output file.
///
/// Only the user-facing message is displayed; the technical log stays in the
/// failure's debug field.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EmptyStateView(
        icon: Icons.error_outline_rounded,
        title: 'Conversion failed',
        message: controller.errorMessage.value.isNotEmpty
            ? controller.errorMessage.value
            : 'Unable to convert this file. Please try another one.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextButton(
              onPressed: () =>
                  Get.until((Route<dynamic> route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationView extends StatelessWidget {
  const _ConfigurationView({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<MediaInfo> sources = controller.sources;

      if (sources.isEmpty) {
        return _EmptySelection(controller: controller);
      }

      return Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              children: <Widget>[
                if (controller.mode.picksMultiple)
                  _MergeList(controller: controller)
                else
                  SourceSummaryCard(
                    media: sources.first,
                    onRemove: () => controller.removeSourceAt(0),
                  ),
                if (controller.mode.picksMultiple) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceMd),
                  OutlinedButton.icon(
                    onPressed: controller.pickSource,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add more files'),
                  ),
                ],
                if (controller.mode.supportsTrim) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceXl),
                  _TrimSection(controller: controller),
                ],
                const SizedBox(height: AppDimens.spaceXl),
                if (controller.mode.isCompression)
                  _CompressionSection(controller: controller)
                else
                  _FormatSection(controller: controller),
                const SizedBox(height: AppDimens.spaceXl),
                _FileNameField(controller: controller),
                Obx(() {
                  final String message = controller.errorMessage.value;
                  if (message.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceLg),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Obx(
              () => FilledButton.icon(
                onPressed: controller.canConvert ? controller.convert : null,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Convert'),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EmptyStateView(
        icon: controller.mode.picksVideo
            ? Icons.video_library_outlined
            : Icons.library_music_outlined,
        title: controller.mode.title,
        message: controller.errorMessage.value.isNotEmpty
            ? controller.errorMessage.value
            : controller.mode.description,
        action: FilledButton.icon(
          onPressed: controller.isPicking.value ? null : controller.pickSource,
          icon: const Icon(Icons.folder_open_rounded),
          label: Text(controller.mode.actionLabel),
        ),
      ),
    );
  }
}

class _MergeList extends StatelessWidget {
  const _MergeList({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.sources.length,
        onReorderItem: controller.reorderSources,
        itemBuilder: (BuildContext context, int index) {
          final MediaInfo media = controller.sources[index];
          return Padding(
            key: ValueKey<String>('${media.path}#$index'),
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: SourceSummaryCard(
              media: media,
              onRemove: () => controller.removeSourceAt(index),
              leading: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(AppDimens.spaceSm),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrimSection extends StatelessWidget {
  const _TrimSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Duration total =
          controller.primarySource?.duration ?? Duration.zero;
      if (total == Duration.zero) {
        return const SizedBox.shrink();
      }

      final double maxMs = total.inMilliseconds.toDouble();
      final double startMs = controller.trimStart.value.inMilliseconds
          .toDouble()
          .clamp(0, maxMs);
      final double endMs = controller.trimEnd.value.inMilliseconds
          .toDouble()
          .clamp(startMs, maxMs);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Selection', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppDimens.spaceSm),
          RangeSlider(
            min: 0,
            max: maxMs,
            values: RangeValues(startMs, endMs),
            labels: RangeLabels(
              Formatters.duration(Duration(milliseconds: startMs.round())),
              Formatters.duration(Duration(milliseconds: endMs.round())),
            ),
            onChanged: (RangeValues values) => controller.setTrimRange(
              Duration(milliseconds: values.start.round()),
              Duration(milliseconds: values.end.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Start ${Formatters.duration(Duration(milliseconds: startMs.round()))}',
              ),
              Text(
                'End ${Formatters.duration(Duration(milliseconds: endMs.round()))}',
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => controller.setTrimRange(Duration.zero, total),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
          ),
        ],
      );
    });
  }
}

class _FormatSection extends StatelessWidget {
  const _FormatSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OptionChips<AudioFormat>(
            title: 'Output format',
            options: controller.mode.availableFormats,
            selected: controller.format.value,
            labelBuilder: (AudioFormat format) => format.label,
            onSelected: controller.setFormat,
          ),
          // Bitrate is meaningless for uncompressed output, so it is hidden
          // rather than shown disabled.
          if (controller.format.value.supportsBitrate) ...<Widget>[
            const SizedBox(height: AppDimens.spaceXl),
            OptionChips<AudioQuality>(
              title: 'Quality',
              options: AudioQuality.values,
              selected: controller.quality.value,
              labelBuilder: (AudioQuality quality) => quality.label,
              onSelected: controller.setQuality,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompressionSection extends StatelessWidget {
  const _CompressionSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Duration? duration = controller.sourceDuration;
      final CompressionLevel level = controller.compressionLevel.value;
      final int? original = controller.primarySource?.sizeInBytes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (original != null)
            Text(
              'Original size: ${Formatters.fileSize(original)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: AppDimens.spaceLg),
          OptionChips<CompressionLevel>(
            title: 'Target quality',
            options: CompressionLevel.values,
            selected: level,
            labelBuilder: (CompressionLevel value) => value.label,
            onSelected: controller.setCompressionLevel,
          ),
          if (duration != null) ...<Widget>[
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Estimated output: about '
              '${Formatters.fileSize(level.estimatedSizeInBytes(duration))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _FileNameField extends StatefulWidget {
  const _FileNameField({required this.controller});

  final ConverterController controller;

  @override
  State<_FileNameField> createState() => _FileNameFieldState();
}

class _FileNameFieldState extends State<_FileNameField> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.fileName.value,
  );

  late final Worker _worker = ever<String>(widget.controller.fileName, (
    String value,
  ) {
    // Keeps the field in sync when a new selection regenerates the name,
    // without fighting the user while they are typing.
    if (_textController.text != value) {
      _textController.text = value;
    }
  });

  @override
  void initState() {
    super.initState();
    _worker;
  }

  @override
  void dispose() {
    _worker.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('File name', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _textController,
          onChanged: widget.controller.setFileName,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Output file name',
            suffixText: '.${widget.controller.format.value.extension}',
          ),
        ),
      ],
    );
  }
}
