import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/services/share_service.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:convertly/features/files/presentation/controllers/files_controller.dart';
import 'package:flutter_test/flutter_test.dart';

MediaFile buildFile(int id, {String? name, int size = 1024}) {
  return MediaFile(
    id: id,
    name: name ?? 'file_$id.mp3',
    originalName: 'source_$id.mp4',
    path: '/out/file_$id.mp3',
    type: MediaFileType.audio,
    format: 'MP3',
    sizeInBytes: size,
    createdAt: DateTime(2026, 8, id.clamp(1, 28)),
    sourceType: MediaSourceType.videoToAudio,
  );
}

class _FakeLibraryRepository implements MediaLibraryRepository {
  _FakeLibraryRepository(this.stored);

  List<MediaFile> stored;
  List<MediaFile>? lastBatchDeleted;
  bool failBatchDelete = false;

  @override
  Future<Result<List<MediaFile>>> getAll() async =>
      Result<List<MediaFile>>.success(List<MediaFile>.from(stored));

  @override
  Future<Result<MediaFile>> add(MediaFile file) async =>
      Result<MediaFile>.success(file);

  @override
  Future<Result<MediaFile>> rename(MediaFile file, String newName) async =>
      Result<MediaFile>.success(file.copyWith(name: newName));

  @override
  Future<Result<void>> delete(MediaFile file) async {
    stored = stored.where((MediaFile item) => item.id != file.id).toList();
    return const Result<void>.success(null);
  }

  @override
  Future<Result<int>> deleteMany(List<MediaFile> files) async {
    lastBatchDeleted = files;
    if (failBatchDelete) {
      return const Result<int>.failure(
        FileFailure(message: 'Those files could not be deleted.'),
      );
    }
    final Set<int?> ids = files.map((MediaFile file) => file.id).toSet();
    stored = stored.where((MediaFile item) => !ids.contains(item.id)).toList();
    return Result<int>.success(files.length);
  }

  @override
  Future<Result<int>> pruneMissing() async => const Result<int>.success(0);
}

FilesController buildController(MediaLibraryRepository repository) {
  return FilesController(
    GetMediaFiles(repository),
    RenameMediaFile(repository),
    DeleteMediaFile(repository),
    DeleteMediaFiles(repository),
    PruneMissingMediaFiles(repository),
    ShareService(),
  );
}

void main() {
  late _FakeLibraryRepository repository;
  late FilesController controller;

  setUp(() async {
    repository = _FakeLibraryRepository(<MediaFile>[
      buildFile(1),
      buildFile(2),
      buildFile(3),
    ]);
    controller = buildController(repository);
    await controller.load(pruneMissing: false);
  });

  group('selection mode', () {
    test('is off until something is ticked', () {
      expect(controller.isSelectionMode, isFalse);
      expect(controller.selectedCount, 0);
    });

    test('a tick turns it on and a second tick turns it off', () {
      final MediaFile file = controller.visibleFiles.first;

      controller.toggleSelection(file);
      expect(controller.isSelectionMode, isTrue);
      expect(controller.isSelected(file), isTrue);

      controller.toggleSelection(file);
      expect(controller.isSelectionMode, isFalse);
      expect(controller.isSelected(file), isFalse);
    });

    test('selectAll ticks every visible file', () {
      controller.selectAll();

      expect(controller.selectedCount, 3);
      expect(controller.isAllSelected, isTrue);
    });

    test('clearSelection leaves selection mode', () {
      controller
        ..selectAll()
        ..clearSelection();

      expect(controller.isSelectionMode, isFalse);
    });

    test('isAllSelected is false while only some are ticked', () {
      controller.toggleSelection(controller.visibleFiles.first);

      expect(controller.isAllSelected, isFalse);
    });
  });

  group('deleteSelected', () {
    test('removes exactly the ticked files', () async {
      final List<MediaFile> visible = controller.visibleFiles;
      controller
        ..toggleSelection(visible[0])
        ..toggleSelection(visible[2]);

      final DeleteSelectionOutcome outcome = await controller.deleteSelected();

      expect(outcome.deletedCount, 2);
      expect(controller.files.map((MediaFile f) => f.id), <int?>[
        visible[1].id,
      ]);
    });

    test('passes the whole selection to the repository in one call', () async {
      controller.selectAll();

      await controller.deleteSelected();

      expect(repository.lastBatchDeleted, hasLength(3));
    });

    test('clears the selection afterwards', () async {
      controller.selectAll();

      await controller.deleteSelected();

      expect(controller.isSelectionMode, isFalse);
      expect(controller.files, isEmpty);
    });

    test('does nothing when nothing is ticked', () async {
      final DeleteSelectionOutcome outcome = await controller.deleteSelected();

      expect(outcome.deletedCount, 0);
      expect(outcome.isFailure, isFalse);
      expect(repository.lastBatchDeleted, isNull);
      expect(controller.files, hasLength(3));
    });

    test(
      'keeps the list intact and clears selection when the delete fails',
      () async {
        repository.failBatchDelete = true;
        controller.selectAll();

        final DeleteSelectionOutcome outcome = await controller
            .deleteSelected();

        expect(outcome.deletedCount, 0);
        expect(outcome.isFailure, isTrue);
        expect(outcome.errorMessage, isNotNull);
        expect(controller.files, hasLength(3));
        expect(controller.isSelectionMode, isFalse);
      },
    );
  });

  test('reloading drops ticks for files that disappeared', () async {
    controller.selectAll();
    expect(controller.selectedCount, 3);

    repository.stored = <MediaFile>[buildFile(1)];
    await controller.load(pruneMissing: false);

    expect(controller.selectedCount, 1);
  });
}
