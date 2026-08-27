/// Thrown by data sources when local persistence cannot be read or written.
class CacheException implements Exception {
  const CacheException([this.message]);

  final String? message;

  @override
  String toString() => 'CacheException: ${message ?? 'unknown'}';
}

/// Thrown by data sources when a file is missing, unreadable or unsupported.
class FileException implements Exception {
  const FileException([this.message]);

  final String? message;

  @override
  String toString() => 'FileException: ${message ?? 'unknown'}';
}
