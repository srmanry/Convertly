import 'package:equatable/equatable.dart';

/// A finished output file.
class ConversionResult extends Equatable {
  const ConversionResult({
    required this.outputPath,
    required this.name,
    required this.sizeInBytes,
    required this.format,
    this.duration,
  });

  final String outputPath;
  final String name;
  final int sizeInBytes;
  final String format;
  final Duration? duration;

  @override
  List<Object?> get props => <Object?>[
    outputPath,
    name,
    sizeInBytes,
    format,
    duration,
  ];
}
