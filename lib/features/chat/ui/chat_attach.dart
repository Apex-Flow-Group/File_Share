import 'package:file_picker/file_picker.dart';

/// Picks files for the message box; they go with the next send. Empty when
/// nothing was picked.
Future<List<String>> pickFilePaths() async {
  final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
  return [for (final f in picked?.files ?? const <PlatformFile>[]) if (f.path != null) f.path!];
}
