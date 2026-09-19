import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/storage_usage.dart';
import '../controllers/storage_controller.dart';

/// What the app is keeping on the device, and how to reclaim it.
class StoragePage extends GetView<StorageController> {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage information')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: controller.refreshUsage,
              child: Obx(() {
                final StorageUsage usage = controller.usage.value;

                return ListView(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  children: <Widget>[
                    _TotalCard(usage: usage, controller: controller),
                    const SizedBox(height: AppDimens.spaceXl),
                    if (usage.byFormat.isNotEmpty) ...<Widget>[
                      Text(
                        'By format',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      for (final StorageGroup group in usage.byFormat)
                        _GroupRow(group: group, total: usage.convertedBytes),
                      const SizedBox(height: AppDimens.spaceXl),
                    ],
                    _WorkingFilesCard(controller: controller, usage: usage),
                    const SizedBox(height: AppDimens.spaceXl),
                    _ClearAllCard(controller: controller, usage: usage),
                    const SizedBox(height: AppDimens.spaceXl),
                    _MessageArea(controller: controller),
                    const SizedBox(height: AppDimens.spaceLg),
                    _SaveLocation(path: usage.outputPath),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// The headline figure: what the app is using in total.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.usage, required this.controller});

  final StorageUsage usage;
  final StorageController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Used by AudioForge', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              Formatters.fileSize(usage.totalBytes),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              '${usage.convertedCount} '
              '${usage.convertedCount == 1 ? 'file' : 'files'} saved in the app',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (usage.missingCount > 0) ...<Widget>[
              const SizedBox(height: AppDimens.spaceSm),
              // These take no space but would otherwise make the file list and
              // this total look like they disagree.
              Text(
                '${usage.missingCount} '
                '${usage.missingCount == 1 ? 'entry is' : 'entries are'} '
                'listed but no longer on the device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            Obx(() {
              if (!controller.isLoading.value) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.only(top: AppDimens.spaceMd),
                child: LinearProgressIndicator(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// One format's share of the converted files.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.total});

  final StorageGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double share = total <= 0 ? 0 : group.bytes / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${group.label}  ·  ${group.fileCount} '
                  '${group.fileCount == 1 ? 'file' : 'files'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                Formatters.fileSize(group.bytes),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: LinearProgressIndicator(value: share, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

/// Leftovers from interrupted conversions, which are always safe to remove.
class _WorkingFilesCard extends StatelessWidget {
  const _WorkingFilesCard({required this.controller, required this.usage});

  final StorageController controller;
  final StorageUsage usage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasAny = usage.workingBytes > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Working files',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  Formatters.fileSize(usage.workingBytes),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Leftovers from conversions that were stopped. Removing them '
              'never touches a finished file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Obx(() {
              // Read first: putting this inside a condition that can
              // short-circuit would leave the Obx watching nothing, which is
              // an error rather than simply a widget that never updates.
              final bool isClearing = controller.isClearing.value;

              return OutlinedButton.icon(
                onPressed: !hasAny || isClearing
                    ? null
                    : controller.clearWorkingFiles,
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text('Remove working files'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Deletes every converted file, behind a confirmation.
class _ClearAllCard extends StatelessWidget {
  const _ClearAllCard({required this.controller, required this.usage});

  final StorageController controller;
  final StorageUsage usage;

  Future<void> _confirm(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete all converted files?'),
        content: Text(
          'This removes ${usage.convertedCount} '
          '${usage.convertedCount == 1 ? 'file' : 'files'} from the device, '
          'freeing ${Formatters.fileSize(usage.convertedBytes)}. '
          'It cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await controller.clearConvertedFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Converted files', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Deleting a file from the Files tab frees its space too; this '
              'clears every one of them at once.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Obx(() {
              final bool isClearing = controller.isClearing.value;

              return OutlinedButton.icon(
                onPressed: usage.convertedCount == 0 || isClearing
                    ? null
                    : () => _confirm(context),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Delete all converted files'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Whatever the last action has to report.
class _MessageArea extends StatelessWidget {
  const _MessageArea({required this.controller});

  final StorageController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      final String error = controller.errorMessage.value;
      final String status = controller.statusMessage.value;

      if (error.isNotEmpty) {
        return Text(
          error,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        );
      }
      if (status.isNotEmpty) {
        return Text(status, style: theme.textTheme.bodyMedium);
      }
      return const SizedBox.shrink();
    });
  }
}

class _SaveLocation extends StatelessWidget {
  const _SaveLocation({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Files are saved in', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          path,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
