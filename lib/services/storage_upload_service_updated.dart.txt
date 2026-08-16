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
  }) async {
    if (bytes.isEmpty) throw Exception('Selected image is empty.');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unable to read selected image.');

    // Keep a useful display resolution for carousel images. The old code
    // repeatedly reduced width (640 -> 560 -> 480 -> 400 -> 320 -> 280 -> 240),
    // which made text-heavy news images blurry. We now preserve resolution
    // longer and reduce JPEG quality first so the 20-image Firestore limit
    // is still respected.
    img.Image resized = decoded;
    if (resized.width > 720 || resized.height > 720) {
      resized = img.copyResize(
        resized,
        width: resized.width >= resized.height ? 720 : null,
        height: resized.height > resized.width ? 720 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    Uint8List jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 45));

    if (jpeg.length > 30 * 1024) {
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 40));
    }
    if (jpeg.length > 30 * 1024) {
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 35));
    }
    if (jpeg.length > 30 * 1024) {
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 30));
    }
    if (jpeg.length > 30 * 1024) {
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 25));
    }
    if (jpeg.length > 30 * 1024) {
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 20));
    }

    // Last fallback: reduce resolution only if the encoded image still
    // exceeds the per-image budget required for a 20-image post.
    if (jpeg.length > 30 * 1024) {
      resized = img.copyResize(
        resized,
        width: 640,
        interpolation: img.Interpolation.linear,
      );
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 20));
    }

    if (jpeg.length > 30 * 1024) {
      throw Exception('Image could not be compressed enough for a 20-image post.');
    }

    final encoded = base64Encode(jpeg);
    return StorageUploadResult(
      dataUrl: 'data:image/jpeg;base64,$encoded',
    );
  }

  static Future<String> urlFromPath(String path) async => '';
}
