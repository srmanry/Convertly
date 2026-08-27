import 'package:file_picker/file_picker.dart';

/// A file the user chose, before validation.
class PickedMedia {
  const PickedMedia({
    required this.name,
    required this.uri,
    required this.sizeInBytes,
  });

  final String name;
  final Uri uri;
  final int sizeInBytes;
}

/// Opens the system file picker.
abstract interface class MediaPickerDataSource {
  Future<PickedMedia?> pickVideo();

  Future<PickedMedia?> pickAudio();

  Future<List<PickedMedia>> pickAudioFiles();
}

class MediaPickerDataSourceImpl implements MediaPickerDataSource {
  const MediaPickerDataSourceImpl();

  @override
  Future<PickedMedia?> pickVideo() => _pickSingle(FileType.video);

  @override
  Future<PickedMedia?> pickAudio() => _pickSingle(FileType.audio);

  @override
  Future<List<PickedMedia>> pickAudioFiles() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
    );

    final List<PickedMedia> picked = <PickedMedia>[];
    for (final PlatformFile file in files) {
      picked.add(await _toPickedMedia(file));
    }
    return picked;
  }

  Future<PickedMedia?> _pickSingle(FileType type) async {
    final PlatformFile? file = await FilePicker.pickFile(type: type);
    // A null result means the user dismissed the picker, which is not an error.
    return file == null ? null : _toPickedMedia(file);
  }

  Future<PickedMedia> _toPickedMedia(PlatformFile file) async {
    return PickedMedia(
      name: file.name,
      uri: file.uri,
      // length() is read from the document provider rather than by loading the
      // file, so this stays cheap for very large media.
      sizeInBytes: await file.length(),
    );
  }
}
