import 'dart:typed_data';

abstract class VisionRepository {
  Future<String> analyzeImage({
    required Uint8List imageBytes,
    required String message,
  });
}