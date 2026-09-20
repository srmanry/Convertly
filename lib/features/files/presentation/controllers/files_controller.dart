import 'dart:io';

import 'package:get/get.dart';

import '../../../shell/presentation/controllers/shell_controller.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/media_export_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/usecases/media_library_usecases.dart';
import '../../../../core/i18n/translation_keys.dart';

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

  /// What the user has typed into the search field. Empty means no filter.
  final RxString query = ''.obs;

  bool get isSearching => query.value.trim().isNotEmpty;

  /// Whether the app bar is showing the search box instead of the title.
  final RxBool searchOpen = false.obs;

  /// Ids the user has ticked. Selection mode is on whenever this is non-empty.
  final RxSet<int> selectedIds = <int>{}.obs;

  bool get isSelectionMode => selectedIds.isNotEmpty;

  int get selectedCount => selectedIds.length;

  /// True when every visible file is ticked, which drives the select-all
  /// toggle rather than a separate flag that could drift out of sync.
  bool get isAllSelected {
    final List<MediaFile> visible = visibleFiles;
    // Every visible row ticked, rather than a count comparison: with a search
    // active the selection can hold files this list is not showing.
    return visible.isNotEmpty && visible.every(isSelected);
  }

  bool isSelected(MediaFile file) =>
      file.id != null && selectedIds.contains(file.id);

  /// Every selected file, whether or not the search is currently showing it.
  ///
  /// Deliberately not built from [visibleFiles]: typing in the search box
  /// would otherwise hide ticked rows from a batch delete, which then cleared
  /// their ticks — leaving files the user had marked, silently undeleted.
  List<MediaFile> get selectedFiles => _sortedFiles
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
    _reloadWhenTabOpens();
  }

  /// Reads the library again each time this tab comes to the front.
  ///
  /// The tabs are kept alive in an IndexedStack, so onInit runs once for the
  /// whole session: without this, a file converted after the app started
  /// would not appear until the list was pulled down by hand.
  void _reloadWhenTabOpens() {
    if (!Get.isRegistered<ShellController>()) {
      return;
    }
    final ShellController shell = Get.find<ShellController>();
    _tabWatcher = ever<ShellTab>(shell.currentTab, (ShellTab tab) {
      if (tab == ShellTab.files) {
        load();
      }
    });
  }

  Worker? _tabWatcher;

  @override
  void onClose() {
    _tabWatcher?.dispose();
    super.onClose();
  }

  /// Everything in the library, in the user's chosen order.
  List<MediaFile> get _sortedFiles {
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

  /// What the list should show: the sorted library, narrowed by the search.
  ///
  /// Matching is case-insensitive and on the file name only — the one field
  /// the user actually reads in the list.
  List<MediaFile> get visibleFiles {
    final String needle = query.value.trim().toLowerCase();
    if (needle.isEmpty) {
      return _sortedFiles;
    }
    return _sortedFiles
        .where((MediaFile file) => file.name.toLowerCase().contains(needle))
        .toList();
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

  void setQuery(String value) => query.value = value;

  void clearQuery() => query.value = '';

  void openSearch() => searchOpen.value = true;

  /// Closing the box also lifts the filter, so a hidden search never keeps
  /// narrowing the list.
  void closeSearch() {
    searchOpen.value = false;
    clearQuery();
  }

  Future<void> open(MediaFile file) async {
    if (!File(file.path).existsSync()) {
      await _removeMissingFile(file);
      return;
    }

    final List<MediaFile> playable = visibleFiles;
    final int index = playable.indexWhere(
      (MediaFile item) => item.path == file.path,
    );

    await Get.toNamed<void>(
      AppRoutes.audioPlayer,
      arguments: <String, Object>{
        'queue': <Map<String, String>>[
          for (final MediaFile item in playable)
            <String, String>{'path': item.path, 'title': item.name},
        ],
        'index': index < 0 ? 0 : index,
      },
    );
  }

  /// Copies [file] into the phone's Music folder.
  ///
  /// The app's own folder is invisible to other apps and is wiped when the
  /// app is uninstalled; this is how a finished track leaves for good.
  Future<bool> saveToPhone(MediaFile file) async {
    if (!Get.isRegistered<MediaExportService>()) {
      return false;
    }
    final String? saved = await Get.find<MediaExportService>().saveToMusic(
      path: file.path,
      name: file.name,
    );
    return saved != null;
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
          K.navFiles.tr,
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
          K.navFiles.tr,
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
      K.navFiles.tr,
      K.errorFileGone.tr,
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
