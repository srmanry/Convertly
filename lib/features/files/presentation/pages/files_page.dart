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
      appBar: AppBar(
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
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceXs,
                        ),
                        leading: const CircleAvatar(
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
                        onTap: () => controller.open(file),
                        trailing: PopupMenuButton<_FileAction>(
                          onSelected: (_FileAction action) async {
                            switch (action) {
                              case _FileAction.play:
                                await controller.open(file);
                              case _FileAction.share:
                                await controller.share(file);
                              case _FileAction.rename:
                                await _showRenameDialog(context, file);
                              case _FileAction.delete:
                                await controller.delete(file);
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
