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

  static Future<StorageUploadResult> uploadCarouselJpeg({
    required String folder,
    required String uid,
    required Uint8List bytes,
    int imageCount = 1,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected image is empty.');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unable to read selected image.');

    // Images are stored as data URLs in the same Firestore document.
    // Use a larger budget for a small post and a smaller budget for a
    // 20-image post so both single-image and multi-image posts work.
    final count = imageCount.clamp(1, 20).toInt();
    final maxBytes = ((650 * 1024) / count).floor();

    final maxDimensions = count >= 16
        ? const [720, 640, 560, 480, 400, 360, 320]
        : count >= 10
            ? const [900, 800, 720, 640, 560, 480, 400]
            : const [1280, 1120, 1024, 900, 800, 720, 640];

    final qualities = count >= 16
        ? const [48, 44, 40, 36, 32, 28, 24, 20]
        : count >= 10
            ? const [58, 54, 50, 46, 42, 38, 34, 30, 26, 22]
            : const [70, 64, 58, 52, 46, 40, 34, 28, 24, 20];

    for (final maxDimension in maxDimensions) {
      img.Image resized = decoded;

      if (resized.width > maxDimension || resized.height > maxDimension) {
        resized = img.copyResize(
          resized,
          width: resized.width >= resized.height ? maxDimension : null,
          height: resized.height > resized.width ? maxDimension : null,
          interpolation: img.Interpolation.linear,
        );
      }

      for (final quality in qualities) {
        final jpeg = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );

        if (jpeg.length <= maxBytes) {
          final encoded = base64Encode(jpeg);
          return StorageUploadResult(
            dataUrl: 'data:image/jpeg;base64,$encoded',
          );
        }
      }
    }

    throw Exception(
      'Image could not be compressed enough for $count-image post.',
    );
  }

  static Future<String> urlFromPath(String path) async => '';
}
