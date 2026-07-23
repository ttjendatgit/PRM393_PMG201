import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        // NOTE: on Flutter Web, a slow synchronous Backend endpoint that sends
        // no response headers until it fully completes is reported by Dio's
        // browser adapter as connectionTimeout, not receiveTimeout — the XHR
        // adapter classifies purely by readyState, not by which timeout
        // phase actually elapsed. So this message must stay neutral; it does
        // NOT reliably mean the backend process is down.
        DioExceptionType.connectionTimeout =>
          'Could not connect to the backend at ${ApiConfig.baseUrl}.',
        DioExceptionType.sendTimeout =>
          'The request could not be sent in time.',
        DioExceptionType.receiveTimeout =>
          'The server took too long to respond.',
        DioExceptionType.connectionError =>
          'Cannot reach the server. Is the backend running at ${ApiConfig.baseUrl}?',
        DioExceptionType.badResponse =>
          'Server returned error ${statusCode ?? 'unknown'}.',
        DioExceptionType.cancel => 'Request was cancelled.',
        _ => e.message ?? 'An unexpected network error occurred.',
      };
    }

    return ApiException(
      message,
      statusCode: statusCode,
      data: data,
      dioErrorType: e.type,
    );
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
    Options? options,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: queryParams,
        options: options,
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

  /// Converts one [PlatformFile] into a Dio [MultipartFile], cross-platform
  /// safe. On Web, `PlatformFile.path` is unusable (no filesystem access)
  /// and `dart:io`-based `MultipartFile.fromFile` throws `UnsupportedError`
  /// ("MultipartFile is only supported where dart:io is available"), so Web
  /// always sends the in-memory `PlatformFile.bytes` via
  /// `MultipartFile.fromBytes`. Desktop/mobile prefer `path` (unchanged
  /// behaviour) and fall back to `bytes` if a path isn't available. Throws
  /// [StateError] with the filename in the message if neither is usable,
  /// instead of silently dropping the file.
  static Future<MultipartFile> _platformFileToMultipart(PlatformFile file) async {
    final bytes = file.bytes;
    if (kIsWeb) {
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Unable to read "${file.name}" in the browser.');
      }
      return MultipartFile.fromBytes(bytes, filename: file.name);
    }
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return MultipartFile.fromFile(path, filename: file.name);
    }
    if (bytes != null && bytes.isNotEmpty) {
      return MultipartFile.fromBytes(bytes, filename: file.name);
    }
    throw StateError('Unable to read "${file.name}".');
  }

  /// Upload multiple files as multipart/form-data from [PlatformFile]s.
  static Future<dynamic> uploadPlatformFiles(
    String path,
    List<PlatformFile> files, {
    String fieldName = 'files',
    Map<String, dynamic>? fields,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final multipartFiles = await Future.wait(files.map(_platformFileToMultipart));
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

  /// Upload a single [PlatformFile] as multipart/form-data. Cross-platform
  /// safe like [uploadPlatformFiles] — see [_platformFileToMultipart].
  static Future<dynamic> uploadPlatformFile(
    String path,
    PlatformFile file, {
    required String fieldName,
    Map<String, dynamic>? extraFields,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final multipartFile = await _platformFileToMultipart(file);
      final formData = FormData.fromMap({
        fieldName: multipartFile,
        if (extraFields != null) ...extraFields,
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
