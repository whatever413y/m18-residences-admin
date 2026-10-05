import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Opens the browser's file picker for [extensions]; `null` when cancelled.
///
/// A cancel is detected by the file input's own `cancel` event only. file_picker's default also treats the
/// window regaining focus as a cancel when the file hasn't arrived 500 ms later, which silently dropped large
/// or not-yet-downloaded files (e.g. OneDrive photos) on the first pick.
Future<({String name, Uint8List bytes})?> pickFile(List<String> extensions) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: extensions,
    webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}
