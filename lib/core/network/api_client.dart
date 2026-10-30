import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;

  ApiClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://10.0.2.2:8000',
                ),
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 90),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            );
}