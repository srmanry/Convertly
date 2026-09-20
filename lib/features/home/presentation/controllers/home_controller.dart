import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/usecases/media_library_usecases.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Home dashboard state.
///
/// Recent files stay empty in Phase 1; the media library lands in Phase 5 and
/// will populate this list through a use case without changing the view.
class HomeController extends GetxController {
  HomeController([this._getMediaFiles]);

  final GetMediaFiles? _getMediaFiles;

  /// How many files the home list shows before handing over to the Files tab.
  ///
  /// Past this the list stops being a glance at recent work and turns into a
  /// second, worse copy of the library.
  static const int recentLimit = 5;

  final RxList<MediaFile> recentFiles = <MediaFile>[].obs;

  /// Everything in the library, not just what is shown here.
  final RxInt libraryCount = 0.obs;

  bool get hasRecentFiles => recentFiles.isNotEmpty;

  /// Whether the library holds more than this list is showing.
  bool get hasMoreFiles => libraryCount.value > recentFiles.length;

  @override
  void onInit() {
    super.onInit();
    loadRecentFiles();
  }

  /// Time-of-day greeting shown in the header.
  String get greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return K.greetingMorning.tr;
    }
    if (hour < 17) {
      return K.greetingAfternoon.tr;
    }
    return K.greetingEvening.tr;
  }

  Future<void> loadRecentFiles() async {
    final GetMediaFiles? getMediaFiles = _getMediaFiles;
    if (getMediaFiles == null) {
      recentFiles.clear();
      libraryCount.value = 0;
      return;
    }

    final Result<List<MediaFile>> result = await getMediaFiles(
      const NoParams(),
    );

    result.fold(
      (Failure _) {
        recentFiles.clear();
        libraryCount.value = 0;
      },
      (List<MediaFile> files) {
        recentFiles.assignAll(files.take(recentLimit));
        libraryCount.value = files.length;
      },
    );
  }
}
