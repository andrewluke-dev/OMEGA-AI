import 'dart:typed_data';

import '../../domain/repositories/vision_repository.dart';
import '../datasources/vision_remote_datasource.dart';

class VisionRepositoryImpl implements VisionRepository {
  final VisionRemoteDataSource remoteDataSource;

  VisionRepositoryImpl(this.remoteDataSource);

  @override
  Future<String> analyzeImage({
    required Uint8List imageBytes,
    required String message,
  }) async {
    return remoteDataSource.analyzeImage(
      imageBytes: imageBytes,
      message: message,
    );
  }
}