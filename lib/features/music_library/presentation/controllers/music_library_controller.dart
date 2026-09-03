import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../domain/entities/song.dart';
import '../../domain/usecases/music_library_usecases.dart';

/// Which set of tracks the list is showing.
enum SongTab { phone, app }

class MusicLibraryController extends GetxController {
  MusicLibraryController(
    this._getDeviceSongs,
    this._getAppSongs,
    this._ensurePermission,
  );

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
    final List<Song> source = tab.value == SongTab.phone
        ? deviceSongs
        : appSongs;
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
    await Get.toNamed<void>(
      AppRoutes.audioPlayer,
      arguments: <String, String>{'path': song.path, 'title': song.title},
    );
  }
}
