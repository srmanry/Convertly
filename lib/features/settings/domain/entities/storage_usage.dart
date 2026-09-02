import 'package:equatable/equatable.dart';

/// How much room one group of files takes up.
class StorageGroup extends Equatable {
  const StorageGroup({
    required this.label,
    required this.bytes,
    required this.fileCount,
  });

  final String label;
  final int bytes;
  final int fileCount;

  @override
  List<Object?> get props => <Object?>[label, bytes, fileCount];
}

/// What the app is currently keeping on the device.
///
/// Sizes are measured from the files themselves rather than from the numbers
/// recorded when they were made, so deleting a file is reflected here even
/// though nothing recalculates the stored metadata.
class StorageUsage extends Equatable {
  const StorageUsage({
    required this.convertedBytes,
    required this.convertedCount,
    required this.workingBytes,
    required this.missingCount,
    required this.byFormat,
    required this.outputPath,
  });

  /// Empty state, shown while the real figures are still being read.
  static const StorageUsage empty = StorageUsage(
    convertedBytes: 0,
    convertedCount: 0,
    workingBytes: 0,
    missingCount: 0,
    byFormat: <StorageGroup>[],
    outputPath: '',
  );

  /// Room taken by finished files the app produced.
  final int convertedBytes;
  final int convertedCount;

  /// Room taken by leftovers from interrupted conversions, which are safe to
  /// remove at any time.
  final int workingBytes;

  /// Entries whose file is no longer on disk, e.g. removed by a file manager.
  /// They take no space but explain a count that looks too high.
  final int missingCount;

  /// Converted files split by output format, largest first.
  final List<StorageGroup> byFormat;

  /// Where finished files are written.
  final String outputPath;

  int get totalBytes => convertedBytes + workingBytes;

  bool get isEmpty => totalBytes == 0 && convertedCount == 0;

  @override
  List<Object?> get props => <Object?>[
    convertedBytes,
    convertedCount,
    workingBytes,
    missingCount,
    byFormat,
    outputPath,
  ];
}
