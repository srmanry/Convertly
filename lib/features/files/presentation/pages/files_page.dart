import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/entities/media_file.dart';
import '../controllers/files_controller.dart';

class FilesPage extends GetView<FilesController> {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Obx is not a PreferredSizeWidget, so the height is declared here and
      // the reactive swap happens inside it.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(
          () => controller.isSelectionMode
              ? _SelectionAppBar(
                  controller: controller,
                  onDelete: () => _confirmDeleteSelected(context),
                )
              : _DefaultAppBar(controller: controller),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Obx(() {
              if (controller.isLoading.value && controller.files.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.value.isNotEmpty &&
                  controller.files.isEmpty) {
                return EmptyStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load files',
                  message: controller.errorMessage.value,
                  action: FilledButton(
                    onPressed: controller.load,
                    child: const Text('Try Again'),
                  ),
                );
              }

              if (controller.visibleFiles.isEmpty) {
                return EmptyStateView(
                  icon: Icons.folder_open_rounded,
                  title: 'No files yet',
                  message: 'Your converted files will appear here.',
                  action: FilledButton.icon(
                    onPressed: controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                );
              }

              final List<MediaFile> files = controller.visibleFiles;

              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    AppDimens.spaceSm,
                    AppDimens.pagePadding,
                    AppDimens.spaceXxl,
                  ),
                  itemCount: files.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.spaceSm),
                  itemBuilder: (BuildContext context, int index) {
                    final MediaFile file = files[index];
                    final bool selected = controller.isSelected(file);

                    return Card(
                      color: selected
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      child: ListTile(
                        selected: selected,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceXs,
                        ),
                        leading: controller.isSelectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) =>
                                    controller.toggleSelection(file),
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.library_music_rounded),
                              ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            file.format.toUpperCase(),
                            Formatters.fileSize(file.sizeInBytes),
                            if (file.duration != null)
                              Formatters.duration(file.duration!),
                            Formatters.date(file.createdAt),
                          ].join(' • '),
                        ),
                        // While selecting, a tap toggles instead of opening
                        // the player, which is the standard Android gesture.
                        onTap: () => controller.isSelectionMode
                            ? controller.toggleSelection(file)
                            : controller.open(file),
                        onLongPress: () => controller.toggleSelection(file),
                        trailing: controller.isSelectionMode
                            ? null
                            : PopupMenuButton<_FileAction>(
                                onSelected: (_FileAction action) async {
                                  switch (action) {
                                    case _FileAction.play:
                                      await controller.open(file);
                                    case _FileAction.share:
                                      await controller.share(file);
                                    case _FileAction.rename:
                                      await _showRenameDialog(context, file);
                                    case _FileAction.delete:
                                      await _confirmDeleteSingle(context, file);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    const <PopupMenuEntry<_FileAction>>[
                                      PopupMenuItem<_FileAction>(
                                        value: _FileAction.play,
                                        child: Text('Play'),
                                      ),
                                      PopupMenuItem<_FileAction>(
                                        value: _FileAction.share,
                                        child: Text('Share'),
                                      ),
                                      PopupMenuItem<_FileAction>(
                                        value: _FileAction.rename,
                                        child: Text('Rename'),
                                      ),
                                      PopupMenuItem<_FileAction>(
                                        value: _FileAction.delete,
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Confirms a single delete before it happens (spec §14).
  Future<void> _confirmDeleteSingle(
    BuildContext context,
    MediaFile file,
  ) async {
    final bool confirmed = await _confirmDelete(
      context,
      title: 'Delete file?',
      message: '"${file.name}" will be permanently deleted from your device.',
    );

    if (confirmed) {
      await controller.delete(file);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final int count = controller.selectedCount;
    if (count == 0) {
      return;
    }

    final bool confirmed = await _confirmDelete(
      context,
      title: count == 1 ? 'Delete file?' : 'Delete $count files?',
      message: count == 1
          ? 'This file will be permanently deleted from your device.'
          : 'These $count files will be permanently deleted from your device.',
    );

    if (!confirmed) {
      return;
    }

    final DeleteSelectionOutcome outcome = await controller.deleteSelected();
    if (!context.mounted) {
      return;
    }

    final String message = switch (outcome) {
      DeleteSelectionOutcome(errorMessage: final String error?) => error,
      DeleteSelectionOutcome(deletedCount: 1) => 'File deleted.',
      DeleteSelectionOutcome(:final int deletedCount) =>
        '$deletedCount files deleted.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Dismissing the dialog counts as "no", never as consent to delete.
    return confirmed ?? false;
  }

  Future<void> _showRenameDialog(BuildContext context, MediaFile file) async {
    final TextEditingController textController = TextEditingController(
      text: file.name,
    );

    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename file'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File name',
              hintText: 'Enter a new file name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (value == null || value.trim() == file.name) {
      return;
    }

    await controller.rename(file, value);
  }
}

enum _FileAction { play, share, rename, delete }

/// The normal app bar, with sorting.
class _DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DefaultAppBar({required this.controller});

  final FilesController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('My Files'),
      actions: <Widget>[
        Obx(
          () => PopupMenuButton<MediaSortOrder>(
            initialValue: controller.sortOrder.value,
            tooltip: 'Sort files',
            onSelected: controller.setSortOrder,
            itemBuilder: (BuildContext context) {
              return MediaSortOrder.values
                  .map(
                    (MediaSortOrder order) => PopupMenuItem<MediaSortOrder>(
                      value: order,
                      child: Text(order.label),
                    ),
                  )
                  .toList();
            },
          ),
        ),
      ],
    );
  }
}

/// Contextual app bar shown while files are ticked.
class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({required this.controller, required this.onDelete});

  final FilesController controller;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        onPressed: controller.clearSelection,
        icon: const Icon(Icons.close_rounded),
      ),
      title: Obx(() => Text('${controller.selectedCount} selected')),
      actions: <Widget>[
        Obx(
          () => IconButton(
            tooltip: controller.isAllSelected ? 'Clear all' : 'Select all',
            onPressed: controller.isAllSelected
                ? controller.clearSelection
                : controller.selectAll,
            icon: Icon(
              controller.isAllSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Delete selected',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}
