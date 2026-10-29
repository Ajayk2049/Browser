import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'env.dart';

/// Centralized Dio client tailored for the multi-threaded download engine.
/// Configured without a fixed baseUrl to fetch arbitrary URLs and chunked streams.
class DioClient {
  DioClient._();

  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: Env.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: Env.receiveTimeoutMs),
        sendTimeout: const Duration(milliseconds: Env.connectTimeoutMs),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Android; Mobile; rv:144.0) Gecko/144.0 Firefox/144.0',
        },
      ),
    );

    dio.interceptors.add(_RedactionLoggingInterceptor());
    return dio;
  }
}

/// Redacts sensitive headers and query tokens during debugging.
class _RedactionLoggingInterceptor extends Interceptor {
  static const _sensitiveKeys = {
    'cookie',
    'set-cookie',
    'authorization',
    'token',
    'secret',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (Env.enableLogging) {
      final safeHeaders = _sanitizeMap(options.headers);
      developer.log(
        '--> ${options.method} ${options.uri} | Headers: $safeHeaders',
        name: 'DioDownloader',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (Env.enableLogging) {
      developer.log(
        '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
        name: 'DioDownloader',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Env.enableLogging) {
      developer.log(
        '<-- ERROR ${err.response?.statusCode ?? 'NO_STATUS'} ${err.requestOptions.method} ${err.requestOptions.uri}: ${err.message}',
        name: 'DioDownloader',
        error: err.error,
      );
    }
    handler.next(err);
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final clean = <String, dynamic>{};
    source.forEach((key, value) {
      if (_sensitiveKeys.contains(key.toLowerCase())) {
        clean[key] = '[REDACTED]';
      } else {
        clean[key] = value;
      }
    });
    return clean;
  }
}
