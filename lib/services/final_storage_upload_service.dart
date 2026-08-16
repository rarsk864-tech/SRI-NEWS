import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Firebase Storage-free image handling. Images are resized/compressed and
/// stored as a data URL in the existing Firestore document.
class StorageUploadResult {
  final String dataUrl;
  const StorageUploadResult({required this.dataUrl});
}

class StorageUploadService {
  static Future<StorageUploadResult> uploadJpeg({
    required String folder,
    required String uid,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected image is empty.');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unable to read selected image.');

    img.Image resized = decoded;
    if (resized.width > 1280 || resized.height > 1280) {
      resized = img.copyResize(
        resized,
        width: resized.width >= resized.height ? 1280 : null,
        height: resized.height > resized.width ? 1280 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    Uint8List jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 62));

    // Firestore documents have a ~1 MiB limit. Keep the encoded payload well
    // below that limit after base64 expansion.
    if (jpeg.length > 620 * 1024) {
      resized = img.copyResize(resized, width: 1024);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 52));
    }
    if (jpeg.length > 620 * 1024) {
      resized = img.copyResize(resized, width: 800);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 48));
    }
    if (jpeg.length > 620 * 1024) {
      resized = img.copyResize(resized, width: 640);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 42));
    }
    if (jpeg.length > 680 * 1024) {
      throw Exception('Image is too large after compression. Please choose another image.');
    }

    final encoded = base64Encode(jpeg);
    return StorageUploadResult(dataUrl: 'data:image/jpeg;base64,$encoded');
  }


  /// Gallery images are kept small enough that up to 20 images can safely
  /// live inside the same Firestore document.
  static Future<StorageUploadResult> uploadJpegGallery({
    required String folder,
    required String uid,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected image is empty.');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unable to read selected image.');

    img.Image resized = decoded;
    if (resized.width > 900 || resized.height > 900) {
      resized = img.copyResize(
        resized,
        width: resized.width >= resized.height ? 900 : null,
        height: resized.height > resized.width ? 900 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    Uint8List jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 55));

    for (final size in [800, 700, 600, 500]) {
      if (jpeg.length <= 24 * 1024) break;
      resized = img.copyResize(
        resized,
        width: size,
        interpolation: img.Interpolation.linear,
      );
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 45));
    }

    if (jpeg.length > 30 * 1024) {
      resized = img.copyResize(resized, width: 450);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 35));
    }

    if (jpeg.length > 32 * 1024) {
      throw Exception('Image is too large after compression.');
    }

    return StorageUploadResult(
      dataUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    );
  }

  static Future<String> urlFromPath(String path) async => '';
}
