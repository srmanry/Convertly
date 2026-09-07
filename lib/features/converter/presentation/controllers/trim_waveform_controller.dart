import 'package:get/get.dart';

import '../../../../core/services/waveform_service.dart';
import '../../domain/entities/media_info.dart';
import 'converter_controller.dart';

/// Holds the decoded waveform for whatever the cutter currently has open.
///
/// Separate from [ConverterController] because decoding is slow and optional:
/// the trim screen works without it, so a failure here must not reach the
/// conversion flow.
class TrimWaveformController extends GetxController {
  TrimWaveformController(this._waveforms);

  final WaveformService _waveforms;

  /// Held as a whole-list value rather than an RxList: the peaks are replaced
  /// wholesale, never edited item by item, and a fresh list identity each time
  /// is what lets the painter tell that the shape actually changed.
  final Rx<List<double>> peaks = Rx<List<double>>(const <double>[]);

  final RxBool isLoading = false.obs;

  /// Path the current peaks describe, so re-entering the screen with the same
  /// file does not decode it again.
  String? _loadedFor;

  Worker? _sourceWatcher;

  @override
  void onInit() {
    super.onInit();
    final ConverterController converter = Get.find<ConverterController>();
    _sourceWatcher = ever<List<MediaInfo>>(
      converter.sources,
      (_) => load(converter.primarySource),
    );
    load(converter.primarySource);
  }

  Future<void> load(MediaInfo? source) async {
    if (source == null) {
      _loadedFor = null;
      peaks.value = const <double>[];
      isLoading.value = false;
      return;
    }

    if (_loadedFor == source.path) {
      return;
    }

    final String requested = source.path;
    _loadedFor = requested;
    peaks.value = const <double>[];
    isLoading.value = true;

    final List<double>? decoded = await _waveforms.peaksFor(requested);

    // The user can swap the file while a decode is in flight; drawing the old
    // track's shape over the new one would be worse than drawing nothing.
    if (_loadedFor != requested) {
      return;
    }

    peaks.value = decoded ?? const <double>[];
    isLoading.value = false;
  }

  @override
  void onClose() {
    _sourceWatcher?.dispose();
    super.onClose();
  }
}
