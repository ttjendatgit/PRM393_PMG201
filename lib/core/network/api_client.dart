import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Singleton Dio wrapper used by all feature services.
///
/// Usage:
///   final data = await ApiClient.get('/api/assessments');
///   final data = await ApiClient.post('/api/auth/login', body: {...});
class ApiClient {
  ApiClient._();

  static final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: const ApiException(
                  'Session expired. Please log in again.',
                  statusCode: 401,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          }
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ── Error mapping ─────────────────────────────────────────────────────────

  static ApiException _mapError(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message;

    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        message = data['message'].toString();
      } else if (data['errors'] != null) {
        // ASP.NET ModelState validation errors: {"errors": {"Field": ["msg"]}}
        final errors = data['errors'];
        if (errors is Map) {
          message = errors.values
              .expand<String>((v) => v is List
                  ? v.map((item) => item.toString())
                  : [v.toString()])
              .join(', ');
        } else {
          message = errors.toString();
        }
      } else if (data['title'] != null) {
        message = data['title'].toString();
      } else {
        message = 'Server error (${statusCode ?? 'unknown'}).';
      }
    } else {
      message = switch (e.type) {
        DioExceptionType.connectionTimeout =>
          'Connection timed out. Make sure the backend is running at ${ApiConfig.baseUrl}',
        DioExceptionType.sendTimeout => 'Request timed out while sending data.',
        DioExceptionType.receiveTimeout => 'Server took too long to respond.',
        DioExceptionType.connectionError =>
          'Cannot reach the server. Is the backend running at ${ApiConfig.baseUrl}?',
        DioExceptionType.badResponse =>
          'Server returned error ${statusCode ?? 'unknown'}.',
        DioExceptionType.cancel => 'Request was cancelled.',
        _ => e.message ?? 'An unexpected network error occurred.',
      };
    }

    return ApiException(message, statusCode: statusCode, data: data);
  }

  // ── Core HTTP methods ─────────────────────────────────────────────────────

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: body,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── File upload ───────────────────────────────────────────────────────────

  /// Upload a single file as multipart/form-data.
  static Future<dynamic> uploadFile(
    String path,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? fields,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final multipartFile = await MultipartFile.fromFile(filePath);
      final formData = FormData.fromMap({
        fieldName: multipartFile,
        if (fields != null) ...fields,
      });
      final response = await _dio.post<dynamic>(
        path,
        data: formData,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Upload multiple files as multipart/form-data.
  static Future<dynamic> uploadFiles(
    String path,
    List<String> filePaths, {
    String fieldName = 'files',
    Map<String, dynamic>? fields,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final multipartFiles = await Future.wait(
        filePaths.map((p) => MultipartFile.fromFile(p)),
      );
      final formData = FormData.fromMap({
        fieldName: multipartFiles,
        if (fields != null) ...fields,
      });
      final response = await _dio.post<dynamic>(
        path,
        data: formData,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Binary download (e.g. Excel export) ──────────────────────────────────

  static Future<List<int>> downloadFile(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
