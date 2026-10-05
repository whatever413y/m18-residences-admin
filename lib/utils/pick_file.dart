import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens the browser's file picker for [extensions] and returns the picked file; `null` when cancelled.
///
/// The hidden file input stays in the page until the pick ends. Safari on iPhone and iPad doesn't report a pick
/// on an input that was removed after opening the picker (what file_picker did, so nothing happened there), and
/// file_picker's other cancel detection, the window regaining focus, dropped large or not-yet-downloaded files
/// (e.g. OneDrive photos). A cancel is only the input's own `cancel` event; browsers without it never finish the
/// future, which leaves the form as it was.
Future<({String name, Uint8List bytes})?> pickFile(List<String> extensions) {
  final completer = Completer<({String name, Uint8List bytes})?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = extensions.map((extension) => '.$extension').join(',');
  // Out of sight but still rendered: some mobile browsers ignore click() on a display:none input.
  input.style
    ..position = 'fixed'
    ..left = '-1000px'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';

  void finish(({String name, Uint8List bytes})? file) {
    input.remove();
    if (!completer.isCompleted) completer.complete(file);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) return finish(null);
      file.arrayBuffer().toDart.then(
        (buffer) => finish((name: file.name, bytes: buffer.toDart.asUint8List())),
        onError: (Object error) {
          input.remove();
          if (!completer.isCompleted) completer.completeError(error);
        },
      );
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

  web.document.body!.append(input);
  input.click();
  return completer.future;
}
