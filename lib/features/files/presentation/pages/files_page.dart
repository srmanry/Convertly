import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/search_field_border.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/native_ad_tile.dart';
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

              // An empty library and an empty search result are different
              // problems, and the message that helps with one is useless for
              // the other.
              if (controller.files.isEmpty) {
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

              return Column(
                children: <Widget>[
                  if (controller.searchOpen.value)
                    _SearchField(controller: controller),
                  Expanded(
                    child: files.isEmpty
                        ? EmptyStateView(
                            icon: Icons.search_off_rounded,
                            title: 'No matching files',
                            message:
                                'Nothing here is called '
                                '"${controller.query.value.trim()}".',
                            action: TextButton(
                              onPressed: controller.clearQuery,
                              child: const Text('Clear search'),
                            ),
                          )
                        : _fileList(context, files),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _fileList(BuildContext context, List<MediaFile> files) {
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
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
        itemBuilder: (BuildContext context, int index) {
          final MediaFile file = files[index];
          final bool selected = controller.isSelected(file);

          // Ads step aside while files are being picked: an ad row
          // in the middle of a selection is an easy mis-tap, and a
          // mis-tapped ad is worse than a missed impression.
          final bool showsAd =
              !controller.isSelectionMode &&
              AdSlots.showsAfter(index, files.length);

          final Widget row = Card(
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
                      onChanged: (_) => controller.toggleSelection(file),
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
                          case _FileAction.saveToPhone:
                            await _saveToPhone(context, file);
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
                              value: _FileAction.saveToPhone,
                              child: Text('Save to phone'),
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

          if (!showsAd) {
            return row;
          }
          return Column(
            children: <Widget>[
              row,
              const SizedBox(height: AppDimens.spaceSm),
              const NativeAdTile(),
            ],
          );
        },
      ),
    );
  }

  /// Copies a file out to the phone, and says where it went.
  Future<void> _saveToPhone(BuildContext context, MediaFile file) async {
    final FilesController controller = Get.find<FilesController>();
    final bool saved = await controller.saveToPhone(file);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Saved to Music / AudioForge on this phone.'
              : 'Could not save that file to the phone.',
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
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceXl,
            vertical: AppDimens.spaceXl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          iconPadding: const EdgeInsets.fromLTRB(
            AppDimens.spaceXl,
            AppDimens.spaceXl,
            AppDimens.spaceXl,
            0,
          ),
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 30,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            AppDimens.spaceXl,
            AppDimens.spaceLg,
            AppDimens.spaceXl,
            0,
          ),
          title: Text(title, textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.fromLTRB(
            AppDimens.spaceXl,
            AppDimens.spaceSm,
            AppDimens.spaceXl,
            AppDimens.spaceXl,
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppDimens.spaceXl,
            0,
            AppDimens.spaceXl,
            AppDimens.spaceXl,
          ),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppDimens.buttonHeight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppDimens.buttonHeight),
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    // Dismissing the dialog counts as "no", never as consent to delete.
    return confirmed ?? false;
  }

  Future<void> _showRenameDialog(BuildContext context, MediaFile file) async {
    final String currentName = FileUtils.baseNameWithoutExtension(file.name);
    final String extension = FileUtils.extensionOf(file.name);

    final String? value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenameFileDialog(initialName: currentName, extension: extension),
    );

    if (value == null || value.trim() == currentName) {
      return;
    }

    await controller.rename(file, value);
  }
}

class _RenameFileDialog extends StatefulWidget {
  const _RenameFileDialog({required this.initialName, required this.extension});

  final String initialName;
  final String extension;

  @override
  State<_RenameFileDialog> createState() => _RenameFileDialogState();
}

class _RenameFileDialogState extends State<_RenameFileDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_canSave) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return AlertDialog(
      scrollable: true,
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceXl,
        vertical: AppDimens.spaceXl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      iconPadding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        AppDimens.spaceXl,
        AppDimens.spaceXl,
        0,
      ),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drive_file_rename_outline_rounded,
          color: colors.primary,
          size: 30,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        AppDimens.spaceLg,
        AppDimens.spaceXl,
        0,
      ),
      title: const Text('Rename file', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        AppDimens.spaceSm,
        AppDimens.spaceXl,
        AppDimens.spaceXl,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Give this file a short, easy-to-find name.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'File name',
              prefixIcon: const Icon(Icons.audio_file_rounded),
              suffixText: widget.extension.isEmpty
                  ? null
                  : '.${widget.extension}',
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        0,
        AppDimens.spaceXl,
        AppDimens.spaceXl,
      ),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppDimens.buttonHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppDimens.buttonHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                ),
                onPressed: _canSave ? _save : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _FileAction { play, saveToPhone, share, rename, delete }

/// The normal app bar, with sorting.
class _DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DefaultAppBar({required this.controller});

  final FilesController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool searching = controller.searchOpen.value;

      return AppBar(
        title: const Text('My Files'),
        actions: <Widget>[
          if (controller.files.isNotEmpty)
            IconButton(
              tooltip: searching ? 'Close search' : 'Search files',
              onPressed: () {
                if (searching) {
                  controller.closeSearch();
                  FocusScope.of(context).unfocus();
                } else {
                  controller.openSearch();
                }
              },
              icon: Icon(
                searching ? Icons.search_off_rounded : Icons.search_rounded,
              ),
            ),
          PopupMenuButton<MediaSortOrder>(
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
        ],
      );
    });
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

/// Search box shown under the app bar while search is open.
///
/// The app bar keeps its title, the search toggle and the sort control; the box
/// sits below them so a search never hides those.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller});

  final FilesController controller;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _field = TextEditingController(
    text: widget.controller.query.value,
  );

  /// Keeps the box in step with the query when something else clears it —
  /// the empty state's "Clear search" button, for one. Without this the
  /// filter would lift while the typed text sat there contradicting it.
  late final Worker _sync = ever<String>(widget.controller.query, (
    String value,
  ) {
    if (_field.text != value) {
      _field.text = value;
    }
  });

  @override
  void initState() {
    super.initState();
    _sync;
  }

  @override
  void dispose() {
    _sync.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.spaceSm,
        AppDimens.pagePadding,
        0,
      ),
      child: Obx(
        () => TextField(
          controller: _field,
          autofocus: true,
          onChanged: widget.controller.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search files',
            prefixIcon: const Icon(Icons.search_rounded),
            border: searchFieldBorder(),
            enabledBorder: searchFieldBorder(),
            focusedBorder: searchFieldBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
            suffixIcon: widget.controller.isSearching
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                    onPressed: widget.controller.clearQuery,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
              vertical: AppDimens.spaceMd,
            ),
          ),
        ),
      ),
    );
  }
}
