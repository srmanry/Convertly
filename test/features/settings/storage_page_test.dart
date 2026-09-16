import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/settings/domain/entities/storage_usage.dart';
import 'package:convertly/features/settings/domain/repositories/storage_repository.dart';
import 'package:convertly/features/settings/domain/usecases/storage_usecases.dart';
import 'package:convertly/features/settings/presentation/controllers/storage_controller.dart';
import 'package:convertly/features/settings/presentation/pages/storage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Reports whatever the test sets, so the screen is exercised without touching
/// the disk.
class FakeStorageRepository implements StorageRepository {
  FakeStorageRepository(this.usage);

  StorageUsage usage;
  int clearedConverted = 0;
  int clearedWorking = 0;

  @override
  Future<Result<StorageUsage>> readUsage() async =>
      Result<StorageUsage>.success(usage);

  @override
  Future<Result<void>> clearWorkingFiles() async {
    clearedWorking++;
    usage = StorageUsage(
      convertedBytes: usage.convertedBytes,
      convertedCount: usage.convertedCount,
      workingBytes: 0,
      missingCount: usage.missingCount,
      byFormat: usage.byFormat,
      outputPath: usage.outputPath,
    );
    return const Result<void>.success(null);
  }

  @override
  Future<Result<int>> clearConvertedFiles() async {
    clearedConverted++;
    final int removed = usage.convertedCount;
    usage = StorageUsage(
      convertedBytes: 0,
      convertedCount: 0,
      workingBytes: usage.workingBytes,
      missingCount: 0,
      byFormat: const <StorageGroup>[],
      outputPath: usage.outputPath,
    );
    return Result<int>.success(removed);
  }
}

void main() {
  late FakeStorageRepository repository;

  tearDown(Get.reset);

  Future<void> pumpStorage(WidgetTester tester, StorageUsage usage) async {
    // Taller than the default surface so the whole screen is laid out; the
    // message area sits below the cards and would not be built otherwise.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    repository = FakeStorageRepository(usage);
    Get.put<StorageController>(
      StorageController(
        GetStorageUsage(repository),
        ClearWorkingFiles(repository),
        ClearConvertedFiles(repository),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const StoragePage()),
    );
    await tester.pumpAndSettle();
  }

  const StorageUsage withFiles = StorageUsage(
    convertedBytes: 8000,
    convertedCount: 2,
    workingBytes: 2500,
    missingCount: 0,
    byFormat: <StorageGroup>[
      StorageGroup(label: 'MP3', bytes: 5000, fileCount: 1),
      StorageGroup(label: 'WAV', bytes: 3000, fileCount: 1),
    ],
    outputPath: '/tmp/AudioForge',
  );

  group('storage screen', () {
    testWidgets('opens on an empty library without throwing', (
      WidgetTester tester,
    ) async {
      // Nothing stored means every clear action is disabled. Reading the
      // disabled state must not stop the screen watching for changes, which
      // is what a short-circuited condition inside an Obx would do.
      await pumpStorage(tester, StorageUsage.empty);

      expect(tester.takeException(), isNull);
      expect(find.text('Used by AudioForge'), findsOneWidget);
      expect(find.text('0 B'), findsWidgets);
    });

    testWidgets('shows the total and the split by format', (
      WidgetTester tester,
    ) async {
      await pumpStorage(tester, withFiles);

      expect(tester.takeException(), isNull);
      expect(find.text('MP3  ·  1 file'), findsOneWidget);
      expect(find.text('WAV  ·  1 file'), findsOneWidget);
      expect(find.text('2 files saved in the app'), findsOneWidget);
    });

    testWidgets(
      'clearing actions are disabled when there is nothing to clear',
      (WidgetTester tester) async {
        await pumpStorage(tester, StorageUsage.empty);

        final Finder clearAll = find.widgetWithText(
          OutlinedButton,
          'Delete all converted files',
        );
        expect(tester.widget<OutlinedButton>(clearAll).onPressed, isNull);
      },
    );

    testWidgets('removing working files re-measures and reports back', (
      WidgetTester tester,
    ) async {
      await pumpStorage(tester, withFiles);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Remove working files'),
      );
      await tester.pumpAndSettle();

      expect(repository.clearedWorking, 1);
      // The figure comes from a fresh read, not from an assumption about what
      // the action freed.
      expect(Get.find<StorageController>().usage.value.workingBytes, 0);
      expect(find.text('Working files removed.'), findsOneWidget);
    });

    testWidgets('deleting everything asks first, then frees the space', (
      WidgetTester tester,
    ) async {
      await pumpStorage(tester, withFiles);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Delete all converted files'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete all converted files?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
      await tester.pumpAndSettle();

      expect(repository.clearedConverted, 1);
      expect(Get.find<StorageController>().usage.value.convertedCount, 0);
      expect(find.text('All converted files deleted.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation deletes nothing', (
      WidgetTester tester,
    ) async {
      await pumpStorage(tester, withFiles);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Delete all converted files'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.clearedConverted, 0);
    });
  });
}
