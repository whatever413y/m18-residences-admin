import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// File types the receipt picker offers.
const receiptExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif', 'heic', 'heif', 'pdf'];

/// Images are shrunk to at most this many pixels on their long edge.
const _maxEdge = 1600;
const _quality = 0.8;

/// The server refuses uploads over 10 MiB.
const maxReceiptBytes = 10 * 1024 * 1024;

/// The HEIC decoder (heic-to, LGPL-3.0), served from `web/vendor/heic-to/` and loaded only when needed.
const _heicDecoderUrl = 'vendor/heic-to/heic-to.js';

/// A receipt ready to upload.
class PreparedReceipt {
  final Uint8List bytes;
  final String filename;
  final String contentType;

  /// Size of the picked file before conversion.
  final int originalSize;

  const PreparedReceipt({required this.bytes, required this.filename, required this.contentType, required this.originalSize});

  bool get wasConverted => bytes.length != originalSize;
}

class ReceiptException implements Exception {
  final String message;

  const ReceiptException(this.message);

  @override
  String toString() => message;
}

/// Prepares a picked receipt for upload: images (including HEIC) are shrunk and re-encoded as WebP
/// (JPEG where the browser can't write WebP); a WebP already smaller than its re-encoding is kept as it is.
/// PDFs are kept as they are.
Future<PreparedReceipt> prepareReceipt(String filename, Uint8List bytes) async {
  final type = sniffReceiptType(bytes);
  if (type == null) {
    throw const ReceiptException('Unsupported file: pick an image (JPEG, PNG, WebP, GIF, AVIF, HEIC) or a PDF');
  }

  if (type == 'application/pdf') {
    if (bytes.length > maxReceiptBytes) throw const ReceiptException('The PDF is larger than 10 MB');
    return PreparedReceipt(bytes: bytes, filename: filename, contentType: type, originalSize: bytes.length);
  }

  final bitmap = type == 'image/heic' ? await _decodeHeic(bytes) : await _decode(bytes, type);
  final (encoded, encodedType) = await _encode(bitmap, maxEdge: _maxEdge, type: 'image/webp');

  // Re-encoding a small WebP can only make it bigger (and blurrier).
  if (type == 'image/webp' && bytes.length <= encoded.length) {
    if (bytes.length > maxReceiptBytes) throw const ReceiptException('The image is larger than 10 MB');
    return PreparedReceipt(bytes: bytes, filename: filename, contentType: type, originalSize: bytes.length);
  }
  if (encoded.length > maxReceiptBytes) throw const ReceiptException('The image is still larger than 10 MB after shrinking it');
  final extension = encodedType == 'image/webp' ? 'webp' : 'jpg';
  return PreparedReceipt(bytes: encoded, filename: '${_baseName(filename)}.$extension', contentType: encodedType, originalSize: bytes.length);
}

/// Payment QR images are shrunk to at most this many pixels on their long edge.
const _qrMaxEdge = 1024;

/// The server refuses payment images over 2 MiB.
const maxQrBytes = 2 * 1024 * 1024;

/// Prepares a picked payment QR image for upload: decoded by the browser (HEIC too), shrunk to at most
/// [_qrMaxEdge] px and encoded as PNG, which keeps a QR code's edges sharp.
Future<Uint8List> prepareQrPng(Uint8List bytes) async {
  final type = sniffReceiptType(bytes);
  if (type == null || type == 'application/pdf') {
    throw const ReceiptException('Unsupported file: pick an image (JPEG, PNG, WebP, GIF, AVIF, HEIC)');
  }
  final bitmap = type == 'image/heic' ? await _decodeHeic(bytes) : await _decode(bytes, type);
  final (encoded, _) = await _encode(bitmap, maxEdge: _qrMaxEdge, type: 'image/png');
  if (encoded.length > maxQrBytes) throw const ReceiptException('The QR image is still larger than 2 MB as PNG; crop it to the QR code');
  return encoded;
}

/// A file's real type from its first bytes (the same rules as the server), or `null` if it isn't a receipt type.
String? sniffReceiptType(Uint8List b) {
  bool startsWith(List<int> prefix, [int offset = 0]) {
    if (b.length < offset + prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (b[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (startsWith('GIF87a'.codeUnits) || startsWith('GIF89a'.codeUnits)) return 'image/gif';
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) return 'image/webp';
  if (startsWith('%PDF-'.codeUnits)) return 'application/pdf';
  if (b.length >= 16 && startsWith('ftyp'.codeUnits, 4)) {
    final size = ByteData.sublistView(b, 0, 4).getUint32(0);
    final end = math.min(math.max(size, 16), b.length);
    final brands = [String.fromCharCodes(b.sublist(8, 12))];
    for (var i = 16; i + 4 <= end; i += 4) {
      brands.add(String.fromCharCodes(b.sublist(i, i + 4)));
    }
    if (brands.any((brand) => brand == 'avif' || brand == 'avis')) return 'image/avif';
    if (brands.any(const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}.contains)) return 'image/heic';
  }
  return null;
}

Future<web.ImageBitmap> _decode(Uint8List bytes, String type) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
  try {
    return await web.window.createImageBitmap(blob).toDart;
  } catch (_) {
    throw const ReceiptException("This browser can't read the image; try a JPEG or PNG");
  }
}

@JS('HeicTo')
external JSFunction? get _heicTo;

Future<web.ImageBitmap> _decodeHeic(Uint8List bytes) async {
  await _loadHeicDecoder();
  final options = JSObject()
    ..setProperty('blob'.toJS, web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/heic')))
    ..setProperty('type'.toJS, 'bitmap'.toJS);
  try {
    final promise = _heicTo!.callAsFunction(null, options) as JSPromise<web.ImageBitmap>;
    return await promise.toDart;
  } catch (_) {
    throw const ReceiptException("This HEIC photo couldn't be read; try exporting it as a JPEG");
  }
}

Future<void>? _heicDecoderLoading;

Future<void> _loadHeicDecoder() {
  if (_heicTo != null) return Future.value();
  return _heicDecoderLoading ??= () {
    final done = Completer<void>();
    final script = web.HTMLScriptElement()..src = _heicDecoderUrl;
    script.onload = ((web.Event _) => done.complete()).toJS;
    script.onerror = ((web.Event _) {
      _heicDecoderLoading = null;
      done.completeError(const ReceiptException("The HEIC decoder couldn't be loaded; check the connection and try again"));
    }).toJS;
    web.document.head!.append(script);
    return done.future;
  }();
}

/// Draws [bitmap] at most [maxEdge] px on its long edge and encodes it as [type]; WebP falls back to JPEG
/// where the browser can't write WebP.
Future<(Uint8List, String)> _encode(web.ImageBitmap bitmap, {required int maxEdge, required String type}) async {
  final scale = math.min(1.0, maxEdge / math.max(bitmap.width, bitmap.height));
  final width = math.max(1, (bitmap.width * scale).round());
  final height = math.max(1, (bitmap.height * scale).round());
  final canvas = web.OffscreenCanvas(width, height);
  final context = canvas.getContext('2d') as web.OffscreenCanvasRenderingContext2D;
  context.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  var blob = await canvas.convertToBlob(web.ImageEncodeOptions(type: type, quality: _quality)).toDart;
  // Browsers that can't write WebP silently return PNG instead.
  if (type == 'image/webp' && blob.type != 'image/webp') {
    blob = await canvas.convertToBlob(web.ImageEncodeOptions(type: 'image/jpeg', quality: _quality)).toDart;
  }
  final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
  return (bytes, blob.type);
}

String _baseName(String filename) {
  final dot = filename.lastIndexOf('.');
  return dot > 0 ? filename.substring(0, dot) : filename;
}
