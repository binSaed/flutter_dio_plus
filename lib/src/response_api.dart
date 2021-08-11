import 'package:api_manger/src/network_api_exception.dart';
import 'package:dio/dio.dart';

class ResponseApi<T> {
  ResponseApi.success(this.data, this.response,
      [this._defaultErrorMessage = 'error'])
      : status = ApiStatus.success;

  ResponseApi.error(this._error, this.response,
      [this._defaultErrorMessage = 'error'])
      : status = ApiStatus.error;

  T data;

  Response<dynamic> response;

  NetworkApiException _error;

  final String _defaultErrorMessage;

  String get error => _error?.message ?? _defaultErrorMessage;

  ApiStatus status;

  bool get isSuccess => status == ApiStatus.success;

  bool get hasError => status == ApiStatus.error;

  bool get isNoData => data == null;

  bool get hasErrorOrNoData => hasError || isNoData;

  int get statusCode => response?.statusCode ?? 500;

  @override
  String toString() {
    if (status == ApiStatus.error) {
      return 'Status: $status \nError: $error \nstatusCode: $statusCode';
    }
    return 'Status: $status \nData: $data \nstatusCode: $statusCode';
  }
}

enum ApiStatus { success, error }
