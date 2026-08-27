import 'dart:io';

import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/usecases/media_library_usecases.dart';

class FilesController extends GetxController {
  FilesController(
    this._getMediaFiles,
    this._renameMediaFile,
    this._deleteMediaFile,
    this._deleteMediaFiles,
    this._pruneMissingMediaFiles,
    this._shareService,
  );

  final GetMediaFiles _getMediaFiles;
  final RenameMediaFile _renameMediaFile;
  final DeleteMediaFile _deleteMediaFile;
  final DeleteMediaFiles _deleteMediaFiles;
  final PruneMissingMediaFiles _pruneMissingMediaFiles;
  final ShareService _shareService;

  final RxList<MediaFile> files = <MediaFile>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<MediaSortOrder> sortOrder = MediaSortOrder.newest.obs;

  /// Ids the user has ticked. Selection mode is on whenever this is non-empty.
  final RxSet<int> selectedIds = <int>{}.obs;

  bool get isSelectionMode => selectedIds.isNotEmpty;

  int get selectedCount => selectedIds.length;

  /// True when every visible file is ticked, which drives the select-all
  /// toggle rather than a separate flag that could drift out of sync.
  bool get isAllSelected {
    final List<MediaFile> visible = visibleFiles;
    return visible.isNotEmpty && selectedIds.length == visible.length;
  }

  bool isSelected(MediaFile file) =>
      file.id != null && selectedIds.contains(file.id);

  /// The selected files, in the order currently shown.
  List<MediaFile> get selectedFiles => visibleFiles
      .where(
        (MediaFile file) => file.id != null && selectedIds.contains(file.id),
      )
      .toList();

  void toggleSelection(MediaFile file) {
    final int? id = file.id;
    // A row with no id was never persisted, so it cannot be batch deleted.
    if (id == null) {
      return;
    }
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll() {
    selectedIds.assignAll(
      visibleFiles.map((MediaFile file) => file.id).whereType<int>(),
    );
  }

  void clearSelection() => selectedIds.clear();

  /// Deletes everything ticked.
  ///
  /// Returns the outcome rather than showing it: presenting a message is the
  /// page's job, which also keeps this testable without a widget binding.
  /// Selection is cleared either way, so the UI cannot keep pointing at rows
  /// that no longer exist.
  Future<DeleteSelectionOutcome> deleteSelected() async {
    final List<MediaFile> targets = selectedFiles;
    if (targets.isEmpty) {
      return const DeleteSelectionOutcome(deletedCount: 0);
    }

    final Result<int> result = await _deleteMediaFiles(targets);
    final Set<int> targetIds = targets
        .map((MediaFile file) => file.id)
        .whereType<int>()
        .toSet();

    final DeleteSelectionOutcome outcome = result.fold(
      (Failure failure) => DeleteSelectionOutcome(
        deletedCount: 0,
        errorMessage: failure.message,
      ),
      (int count) {
        files.removeWhere(
          (MediaFile item) => item.id != null && targetIds.contains(item.id),
        );
        return DeleteSelectionOutcome(deletedCount: count);
      },
    );

    clearSelection();
    return outcome;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<MediaFile> get visibleFiles {
    final List<MediaFile> sorted = List<MediaFile>.from(files);

    switch (sortOrder.value) {
      case MediaSortOrder.newest:
        sorted.sort(
          (MediaFile a, MediaFile b) => b.createdAt.compareTo(a.createdAt),
        );
      case MediaSortOrder.oldest:
        sorted.sort(
          (MediaFile a, MediaFile b) => a.createdAt.compareTo(b.createdAt),
        );
      case MediaSortOrder.name:
        sorted.sort(
          (MediaFile a, MediaFile b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case MediaSortOrder.size:
        sorted.sort(
          (MediaFile a, MediaFile b) => b.sizeInBytes.compareTo(a.sizeInBytes),
        );
    }

    return sorted;
  }

  Future<void> load({bool pruneMissing = true}) async {
    isLoading.value = true;
    errorMessage.value = '';

    if (pruneMissing) {
      await _pruneMissingMediaFiles(const NoParams());
    }

    final Result<List<MediaFile>> result = await _getMediaFiles(
      const NoParams(),
    );

    result.fold((Failure failure) => errorMessage.value = failure.message, (
      List<MediaFile> loaded,
    ) {
      files.assignAll(loaded);
      // Drop ticks for rows that disappeared while the list was refreshing.
      final Set<int> availableIds = loaded
          .map((MediaFile file) => file.id)
          .whereType<int>()
          .toSet();
      selectedIds.removeWhere((int id) => !availableIds.contains(id));
    });

    isLoading.value = false;
  }

  void setSortOrder(MediaSortOrder order) => sortOrder.value = order;

  Future<void> open(MediaFile file) async {
    if (!File(file.path).existsSync()) {
      await _removeMissingFile(file);
      return;
    }

    await Get.toNamed<void>(
      AppRoutes.audioPlayer,
      arguments: <String, String>{'path': file.path, 'title': file.name},
    );
  }

  Future<void> share(MediaFile file) async {
    final bool shared = await _shareService.shareFile(
      file.path,
      subject: file.name,
    );

    if (!shared) {
      await _removeMissingFile(file);
    }
  }

  Future<bool> rename(MediaFile file, String newName) async {
    final Result<MediaFile> result = await _renameMediaFile(
      RenameMediaParams(file: file, newName: newName),
    );

    bool renamed = false;
    result.fold(
      (Failure failure) {
        Get.snackbar(
          'Files',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      (MediaFile updated) {
        final int index = files.indexWhere(
          (MediaFile item) => item.id == file.id,
        );
        if (index != -1) {
          files[index] = updated;
        }
        renamed = true;
      },
    );

    return renamed;
  }

  Future<void> delete(MediaFile file) async {
    final Result<void> result = await _deleteMediaFile(file);

    result.fold(
      (Failure failure) {
        Get.snackbar(
          'Files',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      (_) {
        files.removeWhere((MediaFile item) => item.id == file.id);
      },
    );
  }

  Future<void> _removeMissingFile(MediaFile file) async {
    await _deleteMediaFile(file);
    files.removeWhere((MediaFile item) => item.id == file.id);
    Get.snackbar(
      'Files',
      'This file is no longer available on your device.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

/// What a batch delete did, for the page to report.
class DeleteSelectionOutcome {
  const DeleteSelectionOutcome({required this.deletedCount, this.errorMessage});

  final int deletedCount;
  final String? errorMessage;

  bool get isFailure => errorMessage != null;
}
