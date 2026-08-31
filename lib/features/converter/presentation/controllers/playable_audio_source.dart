import 'package:just_audio/just_audio.dart';

/// Opens whatever string identifies a picked file.
///
/// A device pick is a `content://` URI, a library file is a real path, and a
/// file picked on iOS arrives as a `file://` URI that has to be converted back
/// to a path rather than handed over whole.
///
/// Always returns a UriAudioSource, which is what `setClip` and
/// [ClippingAudioSource] both require.
UriAudioSource playableAudioSource(String source) {
  final Uri? uri = Uri.tryParse(source);
  if (uri == null || !uri.hasScheme) {
    return AudioSource.file(source);
  }
  if (uri.scheme == 'file') {
    return AudioSource.file(uri.toFilePath());
  }
  return AudioSource.uri(uri);
}
