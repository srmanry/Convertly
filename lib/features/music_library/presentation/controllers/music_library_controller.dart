import 'dart:convert';

import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../domain/entities/song.dart';
import '../../domain/usecases/music_library_usecases.dart';

/// Which set of tracks the list is showing.
enum SongTab { phone, app, favourites }

class MusicLibraryController extends GetxController {
  MusicLibraryController(
    this._getDeviceSongs,
    this._getAppSongs,
    this._ensurePermission, {
    this.renameSong,
    this.deleteSong,
    StorageService? storage,
    this.onLibraryChanged,
  }) : _storage = storage {
    try {
      final Object? saved = jsonDecode(
        storage?.readString(favouritesKey) ?? '[]',
      );
      if (saved is List) favouriteIds.addAll(saved.whereType<String>());
    } on FormatException {
      // A damaged preference must not prevent the music library opening.
    }
  }

  static const String favouritesKey = 'music_favourite_ids';
  final RenameSong? renameSong;
  final DeleteSong? deleteSong;
  final StorageService? _storage;
  final Future<void> Function()? onLibraryChanged;
  final RxSet<String> favouriteIds = <String>{}.obs;
  final RxBool isManaging = false.obs;

  bool isFavourite(Song song) => favouriteIds.contains(song.id);

  Future<void> _saveFavourites() async {
    await _storage?.writeString(
      favouritesKey,
      jsonEncode(favouriteIds.toList()),
    );
  }

  Future<bool> toggleFavourite(Song song) async {
    if (isManaging.value) return false;
    isManaging.value = true;
    errorMessage.value = '';
    final bool wasFavourite = isFavourite(song);
    if (wasFavourite) {
      favouriteIds.remove(song.id);
    } else {
      favouriteIds.add(song.id);
    }
    try {
      await _saveFavourites();
      return true;
    } catch (_) {
      if (wasFavourite) {
        favouriteIds.add(song.id);
      } else {
        favouriteIds.remove(song.id);
      }
      errorMessage.value = K.errorProgressNotSaved.tr;
      return false;
    } finally {
      isManaging.value = false;
    }
  }

  Future<bool> rename(Song song, String name) async {
    final RenameSong? rename = renameSong;
    if (isManaging.value || rename == null) return false;
    isManaging.value = true;
    errorMessage.value = '';
    try {
      final Result<Song?> result = await rename(RenameSongParams(song, name));
      final Song? updated = result.valueOrNull;
      if (updated == null) {
        errorMessage.value = result.failureOrNull?.message ?? '';
        return false;
      }
      final RxList<Song> list = song.source == SongSource.app
          ? appSongs
          : deviceSongs;
      final int index = list.indexWhere((Song value) => value.id == song.id);
      if (index >= 0) list[index] = updated;
      if (song.source == SongSource.app) await onLibraryChanged?.call();
      return true;
    } finally {
      isManaging.value = false;
    }
  }

  Future<bool> delete(Song song) async {
    final DeleteSong? remove = deleteSong;
    if (isManaging.value || remove == null) return false;
    isManaging.value = true;
    errorMessage.value = '';
    try {
      final Result<bool> result = await remove(song);
      if (result.valueOrNull != true) {
        errorMessage.value = result.failureOrNull?.message ?? '';
        return false;
      }
      deviceSongs.removeWhere((Song value) => value.id == song.id);
      appSongs.removeWhere((Song value) => value.id == song.id);
      if (favouriteIds.remove(song.id)) {
        try {
          await _saveFavourites();
        } catch (_) {
          // The file is already deleted; do not put it back in the list.
          errorMessage.value = K.errorProgressNotSaved.tr;
        }
      }
      if (song.source == SongSource.app) await onLibraryChanged?.call();
      return true;
    } finally {
      isManaging.value = false;
    }
  }

  final GetDeviceSongs _getDeviceSongs;
  final GetAppSongs _getAppSongs;
  final EnsureDevicePermission _ensurePermission;

  final Rx<SongTab> tab = SongTab.phone.obs;

  final RxList<Song> deviceSongs = <Song>[].obs;
  final RxList<Song> appSongs = <Song>[].obs;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString query = ''.obs;

  /// False until the device's music has actually been allowed.
  ///
  /// Kept separate from an error: being refused is a normal outcome that the
  /// screen answers with an explanation and a button, not a failure message.
  final RxBool hasDeviceAccess = false.obs;

  /// The tracks currently on screen, after the search box.
  List<Song> get visibleSongs {
    final List<Song> source = switch (tab.value) {
      SongTab.phone => deviceSongs,
      SongTab.app => appSongs,
      SongTab.favourites => <Song>[
        ...deviceSongs,
        ...appSongs,
      ].where(isFavourite).toList(),
    };
    final String text = query.value.trim().toLowerCase();
    if (text.isEmpty) {
      return source;
    }
    return source
        .where(
          (Song song) =>
              song.title.toLowerCase().contains(text) ||
              (song.subtitle?.toLowerCase().contains(text) ?? false),
        )
        .toList();
  }

  Worker? _tabWatcher;

  @override
  void onInit() {
    super.onInit();
    load();
    _reloadWhenTabOpens();
  }

  /// Reads both lists again each time this tab comes to the front.
  ///
  /// The tabs live in an IndexedStack and are built once, so a file converted
  /// later would otherwise never show up here.
  void _reloadWhenTabOpens() {
    if (!Get.isRegistered<ShellController>()) {
      return;
    }
    final ShellController shell = Get.find<ShellController>();
    _tabWatcher = ever<ShellTab>(shell.currentTab, (ShellTab tab) {
      if (tab == ShellTab.player) {
        load();
      }
    });
  }

  @override
  void onClose() {
    _tabWatcher?.dispose();
    super.onClose();
  }

  /// Loads both lists. The app's own files never need permission, so they are
  /// read whatever the device answers.
  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';

    await _loadAppSongs();
    await _loadDeviceSongs(askIfNeeded: false);

    isLoading.value = false;
  }

  /// Asks for access, then loads the device's music if it was given.
  Future<void> grantDeviceAccess() async {
    isLoading.value = true;
    errorMessage.value = '';
    await _loadDeviceSongs(askIfNeeded: true);
    isLoading.value = false;
  }

  Future<void> _loadAppSongs() async {
    final Result<List<Song>> result = await _getAppSongs(const NoParams());
    result.fold(
      (Failure failure) => errorMessage.value = failure.message,
      appSongs.assignAll,
    );
  }

  Future<void> _loadDeviceSongs({required bool askIfNeeded}) async {
    if (askIfNeeded) {
      final Result<bool> granted = await _ensurePermission(const NoParams());
      hasDeviceAccess.value = granted.valueOrNull ?? false;
    }

    if (!hasDeviceAccess.value && !askIfNeeded) {
      // Reading without permission throws; the screen shows the prompt
      // instead and asks only when the user chooses to.
      final Result<List<Song>> probe = await _getDeviceSongs(const NoParams());
      final List<Song>? songs = probe.valueOrNull;
      if (songs == null) {
        return;
      }
      hasDeviceAccess.value = true;
      deviceSongs.assignAll(songs);
      return;
    }

    if (!hasDeviceAccess.value) {
      deviceSongs.clear();
      return;
    }

    final Result<List<Song>> result = await _getDeviceSongs(const NoParams());
    result.fold(
      (Failure failure) => errorMessage.value = failure.message,
      deviceSongs.assignAll,
    );
  }

  void setTab(SongTab value) => tab.value = value;

  void setQuery(String value) => query.value = value;

  /// Opens the built-in player on [song].
  Future<void> play(Song song) async {
    // The whole visible list goes with it, so next and previous walk the
    // songs the user can see rather than dead-ending on the one they tapped.
    final List<Song> songs = visibleSongs;
    final int index = songs.indexWhere((Song item) => item.id == song.id);

    await Get.toNamed<void>(
      AppRoutes.audioPlayer,
      arguments: <String, Object>{
        'queue': <Map<String, String>>[
          for (final Song item in songs)
            <String, String>{'path': item.path, 'title': item.title},
        ],
        'index': index < 0 ? 0 : index,
      },
    );
  }
}
