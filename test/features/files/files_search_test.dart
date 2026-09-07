import 'package:convertly/core/services/share_service.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:convertly/features/files/presentation/controllers/files_controller.dart';
import 'package:flutter_test/flutter_test.dart';

MediaFile buildFile(int id, String name) {
  return MediaFile(
    id: id,
    name: name,
    originalName: 'source_$id.mp4',
    path: '/out/$name',
    type: MediaFileType.audio,
    format: 'MP3',
    sizeInBytes: 1024,
    createdAt: DateTime(2026, 8, id.clamp(1, 28)),
    sourceType: MediaSourceType.videoToAudio,
  );
}

class _FakeLibraryRepository implements MediaLibraryRepository {
  _FakeLibraryRepository(this.stored);

  List<MediaFile> stored;
  List<MediaFile>? lastBatchDeleted;

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
      buildFile(1, 'Summer Song.mp3'),
      buildFile(2, 'winter mix.mp3'),
      buildFile(3, 'ringtone.m4a'),
    ]);
    controller = buildController(repository);
    await controller.load(pruneMissing: false);
  });

  group('search', () {
    test('is off until something is typed', () {
      expect(controller.isSearching, isFalse);
      expect(controller.visibleFiles, hasLength(3));
    });

    test('narrows the list to matching names, ignoring case', () {
      controller.setQuery('SUMMER');

      expect(controller.isSearching, isTrue);
      expect(controller.visibleFiles.single.name, 'Summer Song.mp3');
    });

    test('matches anywhere in the name, not just the start', () {
      controller.setQuery('mix');

      expect(controller.visibleFiles.single.name, 'winter mix.mp3');
    });

    test('a query that matches nothing leaves an empty list', () {
      controller.setQuery('podcast');

      expect(controller.visibleFiles, isEmpty);
    });

    test('whitespace alone is not a search', () {
      controller.setQuery('   ');

      expect(controller.isSearching, isFalse);
      expect(controller.visibleFiles, hasLength(3));
    });

    test('clearing restores the whole library', () {
      controller.setQuery('summer');
      controller.clearQuery();

      expect(controller.isSearching, isFalse);
      expect(controller.visibleFiles, hasLength(3));
    });

    test('the chosen sort order still applies inside the results', () {
      controller.setSortOrder(MediaSortOrder.name);
      controller.setQuery('m');

      expect(
        controller.visibleFiles.map((MediaFile file) => file.name).toList(),
        <String>['ringtone.m4a', 'Summer Song.mp3', 'winter mix.mp3'],
      );
    });
  });

  group('search and selection together', () {
    test('a ticked file hidden by a search is still deleted', () async {
      final MediaFile hidden = controller.visibleFiles.firstWhere(
        (MediaFile file) => file.name == 'ringtone.m4a',
      );
      controller.toggleSelection(hidden);

      // The search hides the ticked row, but the tick still stands.
      controller.setQuery('summer');
      expect(controller.visibleFiles, hasLength(1));
      expect(controller.selectedCount, 1);

      final DeleteSelectionOutcome outcome = await controller.deleteSelected();

      expect(outcome.deletedCount, 1);
      expect(
        repository.lastBatchDeleted!.single.name,
        'ringtone.m4a',
        reason: 'the hidden file was ticked, so it must be the one deleted',
      );
      expect(
        controller.files.any((MediaFile file) => file.name == 'ringtone.m4a'),
        isFalse,
      );
    });

    test('selectAll ticks only what the search is showing', () {
      controller.setQuery('mp3');
      controller.selectAll();

      expect(controller.selectedCount, 2);
      expect(controller.isAllSelected, isTrue);
    });

    test('isAllSelected is false while a shown file is unticked', () {
      controller.setQuery('mp3');
      controller.toggleSelection(controller.visibleFiles.first);

      expect(controller.isAllSelected, isFalse);
    });

    test(
      'ticks from a previous search do not make the new results look selected',
      () {
        controller.setQuery('ringtone');
        controller.selectAll();

        controller.setQuery('summer');

        expect(controller.selectedCount, 1);
        expect(controller.isAllSelected, isFalse);
      },
    );
  });

  test('a controller starts with no query', () {
    final FilesController fresh = buildController(repository);

    expect(fresh.query.value, isEmpty);
    expect(fresh.isSearching, isFalse);
  });
}
