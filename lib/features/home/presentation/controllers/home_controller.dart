import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/usecases/media_library_usecases.dart';

/// Home dashboard state.
///
/// Recent files stay empty in Phase 1; the media library lands in Phase 5 and
/// will populate this list through a use case without changing the view.
class HomeController extends GetxController {
  HomeController([this._getMediaFiles]);

  final GetMediaFiles? _getMediaFiles;

  final RxList<MediaFile> recentFiles = <MediaFile>[].obs;

  bool get hasRecentFiles => recentFiles.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadRecentFiles();
  }

  /// Time-of-day greeting shown in the header.
  String get greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  Future<void> loadRecentFiles() async {
    final GetMediaFiles? getMediaFiles = _getMediaFiles;
    if (getMediaFiles == null) {
      recentFiles.clear();
      return;
    }

    final Result<List<MediaFile>> result = await getMediaFiles(
      const NoParams(),
    );

    result.fold(
      (Failure _) {
        recentFiles.clear();
      },
      (List<MediaFile> files) {
        recentFiles.assignAll(files.take(3));
      },
    );
  }
}
