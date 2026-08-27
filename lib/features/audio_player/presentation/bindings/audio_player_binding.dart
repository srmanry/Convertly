import 'package:get/get.dart';

import '../controllers/audio_player_controller.dart';

class AudioPlayerBinding extends Bindings {
  @override
  void dependencies() {
    final Map<Object?, Object?> args = Get.arguments is Map<Object?, Object?>
        ? Get.arguments as Map<Object?, Object?>
        : const <Object?, Object?>{};

    final String path = args['path'] as String? ?? '';
    final String title = args['title'] as String? ?? 'Audio';

    Get.lazyPut<AudioPlayerController>(
      () => AudioPlayerController(path: path, title: title),
    );
  }
}
