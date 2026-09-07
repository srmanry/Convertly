import 'package:just_audio/just_audio.dart';

/// Opens whatever string identifies an audio file.
///
/// A device pick or a song from the phone's music index is a `content://`
/// URI, a library file is a real path, and a file picked on iOS arrives as a
/// `file://` URI that has to be converted back to a path rather than handed
/// over whole. Anything that plays audio has to go through here: reading one
/// of these with setFilePath treats the whole URI as a filename and fails.
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
