import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/services/media_export_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/song.dart';
import '../controllers/music_library_controller.dart';

enum _SongAction { rename, save, share, delete, favourite, details }

Future<void> showSongActions(
  BuildContext context,
  Song song,
  MusicLibraryController controller,
) async {
  if (controller.isManaging.value) return;
  final bool favourite = controller.isFavourite(song);
  final _SongAction? action = await showModalBottomSheet<_SongAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (IconData, String, _SongAction) item
                in <(IconData, String, _SongAction)>[
                  (
                    Icons.drive_file_rename_outline_rounded,
                    K.rename.tr,
                    _SongAction.rename,
                  ),
                  (
                    favourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    favourite ? K.removeFavourite.tr : K.addFavourite.tr,
                    _SongAction.favourite,
                  ),
                  // Both belong to the app's own files only. A song from the
                  // device index is already where saving would put it, and it
                  // is addressed by a content URI, which the share sheet
                  // cannot open as a file: offering either would promise
                  // something that always fails.
                  if (song.source ==
                      SongSource.app) ...<(IconData, String, _SongAction)>[
                    (
                      Icons.download_rounded,
                      K.saveToPhone.tr,
                      _SongAction.save,
                    ),
                    (Icons.share_rounded, K.share.tr, _SongAction.share),
                  ],
                  (
                    Icons.info_outline_rounded,
                    K.fileDetails.tr,
                    _SongAction.details,
                  ),
                  (
                    Icons.delete_outline_rounded,
                    K.delete.tr,
                    _SongAction.delete,
                  ),
                ])
              ListTile(
                leading: Icon(
                  item.$1,
                  color: item.$3 == _SongAction.delete
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                title: Text(item.$2),
                onTap: () => Navigator.pop(sheetContext, item.$3),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  bool success = true;
  switch (action) {
    case _SongAction.favourite:
      success = await controller.toggleFavourite(song);
    case _SongAction.rename:
      final String? name = await _renameDialog(context, song);
      if (name == null) return;
      success = await controller.rename(song, name);
    case _SongAction.delete:
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(K.deleteFileTitle.tr),
          content: Text('${song.title}\n\n${K.deleteFileMessage.tr}'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(K.cancel.tr),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(K.delete.tr),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      success = await controller.delete(song);
    case _SongAction.save:
      success = await _saveToPhone(context, song);
    case _SongAction.share:
      await _share(context, song);
    case _SongAction.details:
      await _showDetails(context, song);
  }
  if (!success && context.mounted && controller.errorMessage.value.isNotEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(controller.errorMessage.value)));
  }
}

/// Copies the track into the phone's own Music folder.
///
/// Until this is done the file lives only in the app's folder, which no other
/// app can see and which Android clears when the app is uninstalled.
///
/// Returns true so the caller does not also report a failure: the outcome is
/// already on screen either way.
Future<bool> _saveToPhone(BuildContext context, Song song) async {
  final String? saved = Get.isRegistered<MediaExportService>()
      ? await Get.find<MediaExportService>().saveToMusic(
          path: song.path,
          name: song.fileName ?? song.title,
        )
      : null;

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null ? K.couldNotSaveToPhone.tr : K.savedToPhoneMessage.tr,
        ),
      ),
    );
  }
  return true;
}

/// Hands the file to the phone's share sheet.
Future<void> _share(BuildContext context, Song song) async {
  final bool shared = Get.isRegistered<ShareService>()
      ? await Get.find<ShareService>().shareFile(song.path, subject: song.title)
      : false;

  if (!shared && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(K.fileNoLongerAvailable.tr)));
  }
}

Future<String?> _renameDialog(BuildContext context, Song song) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameSongDialog(song: song),
    );

class _RenameSongDialog extends StatefulWidget {
  const _RenameSongDialog({required this.song});
  final Song song;

  @override
  State<_RenameSongDialog> createState() => _RenameSongDialogState();
}

class _RenameSongDialogState extends State<_RenameSongDialog> {
  late final TextEditingController input = TextEditingController(
    text: FileUtils.baseNameWithoutExtension(
      widget.song.fileName ?? widget.song.title,
    ),
  );
  final GlobalKey<FormState> form = GlobalKey<FormState>();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void save() {
      if (form.currentState!.validate()) {
        Navigator.pop(context, input.text.trim());
      }
    }

    return AlertDialog(
      scrollable: true,
      title: Text(K.renameFile.tr),
      content: Form(
        key: form,
        child: TextFormField(
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: K.fileNameLabel.tr),
          validator: (String? value) =>
              FileUtils.sanitizeFileName(value ?? '') == null
              ? K.errorInvalidFileName.tr
              : null,
          onFieldSubmitted: (_) => save(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(K.cancel.tr),
        ),
        FilledButton(onPressed: save, child: Text(K.save.tr)),
      ],
    );
  }
}

Future<void> _showDetails(BuildContext context, Song song) {
  final DateTime? date = song.createdAt;
  final MaterialLocalizations dates = MaterialLocalizations.of(context);
  final List<(String, String)> rows = <(String, String)>[
    (K.labelFile.tr, song.fileName ?? song.title),
    (
      K.labelSize.tr,
      song.sizeInBytes == null
          ? K.notAvailable.tr
          : Formatters.fileSize(song.sizeInBytes!),
    ),
    (
      K.labelDuration.tr,
      song.duration == null
          ? K.notAvailable.tr
          : Formatters.duration(song.duration!),
    ),
    (K.labelFormat.tr, song.format ?? K.notAvailable.tr),
    (
      song.source == SongSource.app ? K.createdInApp.tr : K.dateAdded.tr,
      date == null
          ? K.notAvailable.tr
          : '${dates.formatFullDate(date)} · ${dates.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
    ),
    (
      K.fileSource.tr,
      song.source == SongSource.app ? K.sourceInApp.tr : K.sourcePhone.tr,
    ),
  ];
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(K.fileDetails.tr),
      content: SizedBox(
        width: AppDimens.maxContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final (String label, String value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    SelectableText(value),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(K.done.tr),
        ),
      ],
    ),
  );
}
