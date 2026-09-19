import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ad_free_button.dart';
import '../../../../core/services/media_export_service.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../domain/entities/conversion_result.dart';

/// Confirmation screen shown after a successful conversion.
class ConversionResultPage extends StatelessWidget {
  const ConversionResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ConversionResult? result = Get.arguments as ConversionResult?;
    if (result == null) {
      // Reached only if the route is opened without arguments, e.g. by a
      // deep link; going back is the sane recovery.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: Get.back<void>,
            child: const Text('Go Back'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conversion Complete')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            // Scrolls when the screen is too short for everything, so a small
            // phone or a large font never overflows; on a tall screen the
            // spacers still centre the result and pin the buttons low.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - AppDimens.pagePadding * 2,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: <Widget>[
                          const Spacer(),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceXl),
                          Text(
                            'Conversion Complete',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppDimens.spaceXl),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppDimens.spaceLg),
                              child: Column(
                                children: <Widget>[
                                  _DetailRow(
                                    label: 'File',
                                    value: result.name,
                                    maxLines: 2,
                                  ),
                                  _DetailRow(
                                    label: 'Size',
                                    value: Formatters.fileSize(
                                      result.sizeInBytes,
                                    ),
                                  ),
                                  if (result.duration
                                      case final Duration duration)
                                    _DetailRow(
                                      label: 'Duration',
                                      value: Formatters.duration(duration),
                                    ),
                                  _DetailRow(
                                    label: 'Format',
                                    value: result.format,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () => Get.toNamed<void>(
                              AppRoutes.audioPlayer,
                              arguments: <String, String>{
                                'path': result.outputPath,
                                'title': result.name,
                              },
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play Audio'),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          OutlinedButton.icon(
                            onPressed: () => _saveToPhone(context, result),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Save to phone'),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          OutlinedButton.icon(
                            onPressed: () => _share(context, result),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share'),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          // The moment a file is ready is when more files are on the
                          // user's mind, so the offer to make them ad-free sits here.
                          const AdFreeButton(),
                          const SizedBox(height: AppDimens.spaceSm),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextButton(
                                  onPressed: _openFiles,
                                  child: const Text('Open Files'),
                                ),
                              ),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Get.until(
                                    (Route<dynamic> r) => r.isFirst,
                                  ),
                                  child: const Text('Done'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Copies the finished file into the phone's Music folder.
  ///
  /// Until this is done the file lives only in the app's own folder, which no
  /// other app can see and which Android clears on uninstall.
  Future<void> _saveToPhone(
    BuildContext context,
    ConversionResult result,
  ) async {
    final String? saved = await Get.find<MediaExportService>().saveToMusic(
      path: result.outputPath,
      name: result.name,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Could not save that file to the phone.'
              : 'Saved to Music / AudioForge on this phone.',
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, ConversionResult result) async {
    final bool shared = await Get.find<ShareService>().shareFile(
      result.outputPath,
      subject: result.name,
    );
    if (!shared && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file is no longer available.')),
      );
    }
  }

  void _openFiles() {
    Get.until((Route<dynamic> route) => route.isFirst);
    if (Get.isRegistered<ShellController>()) {
      Get.find<ShellController>().goToFiles();
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.maxLines});

  final String label;
  final String value;

  /// Caps a long value, which then ends in an ellipsis. Null shows it all.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
