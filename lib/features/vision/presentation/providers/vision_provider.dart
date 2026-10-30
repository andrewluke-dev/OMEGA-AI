import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/vision_remote_datasource.dart';
import '../../data/repositories/vision_repository_impl.dart';
import '../../domain/repositories/vision_repository.dart';

final visionRepositoryProvider = Provider<VisionRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  return VisionRepositoryImpl(
    VisionRemoteDataSource(dio),
  );
});