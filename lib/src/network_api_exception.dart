import 'package:dio/dio.dart';

class NetworkApiException implements Exception {
  final String _message;
  final String _defaultErrorMessage;
  final Response<dynamic> response;

  NetworkApiException(this._message, this.response,
      [this._defaultErrorMessage]);

  int get statusCode => response?.statusCode ?? 500;

  String get message => _message ?? _defaultErrorMessage;

  @override
  String toString() {
    return 'NetworkApiException{message: $message, statusCode: $statusCode}';
  }
}
