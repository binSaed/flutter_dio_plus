import 'package:api_manger/src/network_api_exception.dart';
import 'package:dio/dio.dart';

class ResponseApi<T> {
  ResponseApi.success(this.data, this.response,
      [this._defaultErrorMessage = 'error'])
      : status = ApiStatus.SUCCESS;

  ResponseApi.error(this._error, this.response,
      [this._defaultErrorMessage = 'error'])
      : status = ApiStatus.ERROR;

  T data;

  Response<dynamic> response;

  NetworkApiException _error;

  final String _defaultErrorMessage;

  String get error => _error?.message ?? _defaultErrorMessage;

  ApiStatus status;

  bool get hasError => status == ApiStatus.ERROR;

  bool get isNoData => data == null;

  bool get hasErrorOrNoData => hasError || isNoData;

  int get statusCode => response?.statusCode ?? 500;

  @override
  String toString() {
    if (status == ApiStatus.ERROR) {
      return 'Status: $status \nError: $error \nstatusCode: $statusCode';
    }
    return 'Status: $status \nData: $data \nstatusCode: $statusCode';
  }
}

enum ApiStatus { SUCCESS, ERROR }
