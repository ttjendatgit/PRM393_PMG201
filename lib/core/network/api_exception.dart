import 'package:dio/dio.dart' show DioExceptionType;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data, this.dioErrorType});

  final String message;
  final int? statusCode;
  final dynamic data;
  /// The underlying Dio error type (e.g. connectionTimeout, receiveTimeout),
  /// preserved so callers can distinguish timeout kinds without parsing [message].
  final DioExceptionType? dioErrorType;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isTimeout =>
      dioErrorType == DioExceptionType.connectionTimeout ||
      dioErrorType == DioExceptionType.receiveTimeout ||
      dioErrorType == DioExceptionType.sendTimeout;

  @override
  String toString() => message;
}
