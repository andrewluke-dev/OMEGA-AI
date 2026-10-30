import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class VisionRemoteDataSource {
  final Dio dio;

  VisionRemoteDataSource(this.dio);

  Future<String> analyzeImage({
    required Uint8List imageBytes,
    required String message,
  }) async {
    final encodedImage = base64Encode(imageBytes);

    final response = await dio.post(
      '/vision',
      data: {
        'image_base64': encodedImage,
        'message': message,
      },
    );

    final data = response.data;

    if (data is! Map || data['response'] is! String) {
      throw const FormatException(
        'Răspuns Vision AI invalid.',
      );
    }

    return data['response'] as String;
  }
}