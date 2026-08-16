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

    Uint8List jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 55));

    // Firestore documents are limited to about 1 MiB. Keep a single-image
    // payload comfortably below that limit.
    const maxJpegBytes = 120 * 1024;

    if (jpeg.length > maxJpegBytes) {
      resized = img.copyResize(resized, width: 1024);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 45));
    }
    if (jpeg.length > maxJpegBytes) {
      resized = img.copyResize(resized, width: 800);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 38));
    }
    if (jpeg.length > maxJpegBytes) {
      resized = img.copyResize(resized, width: 640);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 32));
    }
    if (jpeg.length > maxJpegBytes) {
      resized = img.copyResize(resized, width: 480);
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 26));
    }
    if (jpeg.length > maxJpegBytes) {
      throw Exception('Image is too large after compression. Please choose another image.');
    }

    final encoded = base64Encode(jpeg);
    return StorageUploadResult(dataUrl: 'data:image/jpeg;base64,$encoded');
  }

  static Future<StorageUploadResult> uploadCarouselJpeg({
    required String folder,
    required String uid,
    required Uint8List bytes,
    int? imageCount,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected image is empty.');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unable to read selected image.');

    img.Image resized = decoded;

    if (resized.width > 640 || resized.height > 640) {
      resized = img.copyResize(
        resized,
        width: resized.width >= resized.height ? 640 : null,
        height: resized.height > resized.width ? 640 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    const maxJpegBytes = 20 * 1024;

    Uint8List jpeg =
        Uint8List.fromList(img.encodeJpg(resized, quality: 38));

    final attempts = <Map<String, int>>[
      {'width': 560, 'quality': 34},
      {'width': 480, 'quality': 30},
      {'width': 400, 'quality': 27},
      {'width': 320, 'quality': 24},
      {'width': 280, 'quality': 21},
      {'width': 240, 'quality': 18},
      {'width': 200, 'quality': 16},
      {'width': 180, 'quality': 14},
    ];

    for (final attempt in attempts) {
      if (jpeg.length <= maxJpegBytes) break;

      resized = img.copyResize(resized, width: attempt['width']!);
      jpeg = Uint8List.fromList(
        img.encodeJpg(resized, quality: attempt['quality']!),
      );
    }

    if (jpeg.length > maxJpegBytes) {
      throw Exception(
        'Image could not be compressed enough for this post.',
      );
    }

    final encoded = base64Encode(jpeg);
    return StorageUploadResult(
      dataUrl: 'data:image/jpeg;base64,$encoded',
    );
  }

  static Future<String> urlFromPath(String path) async => '';
}
