import 'dart:io';

/// Where received bytes go. Passed in, so tests use their own folders and the
/// app chooses per system (MediaStore on Android, the save folder elsewhere).
class ReceiveStore {
  const ReceiveStore({required this.tempFolder, required this.place});

  /// The app's own folder for files still arriving.
  final Future<Directory> Function() tempFolder;

  /// Moves a complete temp file to its final place without replacing any
  /// existing file, and returns the final path. [name] is already clean.
  final Future<String> Function(File temp, String name) place;
}
