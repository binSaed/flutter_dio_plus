import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dio_plus/src/api_util.dart';
import 'package:flutter_dio_plus/src/base_cache_api_db.dart';
import 'package:flutter_dio_plus/src/future_queue.dart';
import 'package:flutter_dio_plus/src/network_api_exception.dart';
import 'package:flutter_dio_plus/src/response_api.dart';

import 'interceptors/interceptors.dart';

// Must be top-level function
dynamic _parseAndDecode(String response) {
  return jsonDecode(response);
}

Future<dynamic> _parseJsonCompute(String text) {
  return compute(_parseAndDecode, text);
}

class DioPlus {
  DioPlus(
    this._dio, {
    @required this.errorGeneralParser,
    @required this.persistenceCacheDB,
    @required this.getAuthHeader,
    @required this.getDefaultHeader,
    @required this.defaultErrorMessage,
    @required this.networkErrorMessage,
    @required this.noDataMessage,
    @required this.retryBtnMessage,
    @required this.connectionTimeOutMessage,
    @required this.receivingTimeOutMessage,
    @required this.sendingTimeOutMessage,
    this.isDevelopment = false,

    /// if response body Length > largeResponseLength package will parse response in another isolate(Thread)
    /// may take much time but it will improve rendering performance
    /// see my last comment about it in Linkedin => https://bit.ly/3pGcyzC
    int largeResponseLength = 100000,
    this.onNetworkChanged,
  }) {
    if (isDevelopment) {
      _dio.interceptors.add(LogInterceptorX(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        logPrint: print,
      ));
    }

    (_dio.transformer as DefaultTransformer).jsonDecodeCallback = (text) {
      if (text.length > largeResponseLength) return _parseJsonCompute(text);
      return _parseAndDecode(text);
    };
    // to ignore onNetworkChanged in firstCall
    Future.delayed(const Duration(seconds: 2)).then((_) {
      Connectivity()
          .onConnectivityChanged
          .distinct()
          .listen((ConnectivityResult connectivityResult) {
        final bool _connected = connectivityResult != ConnectivityResult.none;

        onNetworkChanged?.call(_connected, connectivityResult);
      });
    });
  }

  final Dio _dio;

  /// if true we will print some information to know what happens
  final bool isDevelopment;

  /// used to make persistenceCache
  final BaseApiCacheDb persistenceCacheDB;

  ///send when auth=true
  final FutureOr<Map<String, String>> Function() getAuthHeader;

  ///use it when u need to send header Like [accept language]
  final FutureOr<Map<String, String>> Function() getDefaultHeader;

  /// return when errorGeneralParser or errorParser return null
  final String Function() defaultErrorMessage;

  /// return when SocketException
  final String Function() networkErrorMessage;

  /// used with ResponseApiBuilder when no data
  final String Function() noDataMessage;

  /// used with ResponseApiBuilder when req is not successful
  final String Function() retryBtnMessage;

  /// When DioErrorType is connectTimeout
  final String Function() connectionTimeOutMessage;

  /// When DioErrorType is sendTimeout
  final String Function() sendingTimeOutMessage;

  /// When DioErrorType is receiveTimeout
  final String Function() receivingTimeOutMessage;

  /// if ur backend used the same error structure
  /// u need to define how to parsing it
  /// also, u can override it in every request
  final String Function(dynamic body, int statusCode) errorGeneralParser;

  /// listen to network connectivity
  /// true == connected to wifi or mobile network
  /// false == no internet
  final void Function(bool connected, ConnectivityResult connectivityResult)
      onNetworkChanged;

  /// used to save response in memory
  final Map<String, dynamic> _httpCaching = HashMap<String, dynamic>();

  Future<ResponseApi<T>> _guardSendRequest<T>({
    Future<_ResponseWithDataSource> Function() request,
    dynamic Function(dynamic body) editBody,
    T Function(dynamic body) parserFunction,
  }) async {
    try {
      final res = await request();
      dynamic body = res.response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        data: _parse(body, parserFunction),
        response: res.response,
        dataSource: res.dataSource,
        defaultErrorMessage: defaultErrorMessage?.call(),
        noDataMessage: noDataMessage?.call(),
        retryBtnMessage: retryBtnMessage?.call(),
      );
    } catch (e, stacktrace) {
      if (isDevelopment && (e is! NetworkApiException)) {
        print('ApiManger: $e \n$stacktrace');
      }
      return ResponseApi<T>.error(
        exception: e,
        response: e?.response,
        defaultErrorMessage: defaultErrorMessage?.call(),
        noDataMessage: noDataMessage?.call(),
        retryBtnMessage: retryBtnMessage?.call(),
      );
    }
  }

  Future<ResponseApi<T>> post<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    dynamic postBody,
    ProgressCallback onSendProgress,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              body: postBody,
              queue: queue,
              onSendProgress: onSendProgress,
              method: 'POST',
              errorParser: errorParser,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  Future<ResponseApi<T>> patch<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    dynamic dataBody,
    ProgressCallback onSendProgress,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              body: dataBody,
              queue: queue,
              onSendProgress: onSendProgress,
              method: 'patch',
              errorParser: errorParser,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  Future<ResponseApi<T>> put<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    dynamic dataBody,
    ProgressCallback onSendProgress,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              body: dataBody,
              queue: queue,
              onSendProgress: onSendProgress,
              method: 'PUT',
              errorParser: errorParser,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  ///first time get data from api and cache it in memory if statusCode >=200<300
  ///any other time response will return from cache
  @Deprecated('use get with memoryCache: true instead of  getWithCache')
  Future<ResponseApi<T>> getWithCache<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              memoryCache: true,
              queue: queue,
              method: 'GET',
              errorParser: errorParser,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  Future<ResponseApi<T>> get<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    bool auth = false,
    bool queue = false,
    bool memoryCache = false,
    bool persistenceCache = false,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              queue: queue,
              memoryCache: memoryCache,
              persistenceCache: persistenceCache,
              method: 'GET',
              errorParser: errorParser,
              queryParameters: queryParameters,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  Future<ResponseApi<T>> delete<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    dynamic dataBody,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    return await _guardSendRequest(
        request: () => _sendRequestImpl(
              url,
              auth: auth,
              headers: headers,
              queue: queue,
              body: dataBody,
              method: 'delete',
              errorParser: errorParser,
            ),
        editBody: editBody,
        parserFunction: parserFunction);
  }

  T _parse<T>(dynamic body, T Function(dynamic body) parserFunction) {
    if (parserFunction == null) return body;

    try {
      return parserFunction(body);
    } catch (e, stacktrace) {
      if (e is FormatException || e is TypeError || e is NoSuchMethodError) {
        if (isDevelopment)
          print('ApiManger: parserFunction=> $e \n$stacktrace');

        return throw NetworkApiException(null, null, defaultErrorMessage());
      }
      throw NetworkApiException(e.toString(), null, defaultErrorMessage());
    }
  }

  dynamic _getFromMemoryCache(String hash) {
    return _httpCaching[hash];
  }

  Future<Response<dynamic>> _getFromPersistenceCache(String hash) async {
    try {
      return responseFromRawJson(await persistenceCacheDB?.get(hash));
    } catch (e, stacktrace) {
      if (isDevelopment) {
        print('ApiManger: _getFromPersistenceCache=> $e \n$stacktrace');
      }

      return null;
    }
  }

  bool _validResponse(int statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  void _saveToMemoryCache(Response<dynamic> res, String hash) {
    if (_validResponse(res.statusCode)) {
      _httpCaching[hash] = res;
    }
  }

  Future<void> _saveToPersistenceCache(
      Response<dynamic> res, String hash) async {
    if (_validResponse(res.statusCode)) {
      await persistenceCacheDB?.add(
        hash,
        responseToRawJson(res),
      );
    }
  }

  String _getCacheHash(String url, String method, Map<String, String> headers,
      {dynamic body}) {
    final allPram = '$url+ $method+ $headers+ $body';

    return _generateMd5(allPram);
  }

  String _generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<_ResponseWithDataSource> _sendRequestImpl(
    String url, {
    @required String method,
    Map<String, String> headers = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, String>{},
    bool auth = false,
    bool memoryCache = false,
    bool persistenceCache = false,
    bool queue = false,
    ProgressCallback onSendProgress,
    dynamic body,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    final Map<String, String> _headers = <String, String>{
      ...headers,
      ...auth ? await getAuthHeader?.call() ?? {} : <String, String>{},
      ...await getDefaultHeader?.call() ?? {},
    };
    final String cacheHash = _getCacheHash(url, method, _headers, body: body);
    try {
      if (memoryCache) {
        final dynamic dataFromCache = _getFromMemoryCache(cacheHash);
        if (dataFromCache != null)
          return _ResponseWithDataSource(
            response: dataFromCache,
            dataSource: DataSource.memoryCache,
          );
      }

      Response<dynamic> _res;
      if (queue) {
        _res = await ApiFutureQueue().run(
          () => _dio.request(
            url,
            options: Options(headers: _headers, method: method),
            data: body,
            onSendProgress: onSendProgress,
            queryParameters: queryParameters,
          ),
        );
      } else {
        _res = await _dio.request(
          url,
          options: Options(headers: _headers, method: method),
          data: body,
          onSendProgress: onSendProgress,
          queryParameters: queryParameters,
        );
      }

      if (memoryCache) _saveToMemoryCache(_res, cacheHash);
      if (persistenceCache) await _saveToPersistenceCache(_res, cacheHash);
      return _ResponseWithDataSource(
        response: _res,
        dataSource: DataSource.internet,
      );
    } catch (error) {
      final dynamic dataFromCache = await _getCacheIfSocketException(
        error,
        persistenceCache,
        cacheHash,
      );
      if (dataFromCache != null)
        return _ResponseWithDataSource(
          response: dataFromCache,
          dataSource: DataSource.persistenceCache,
        );

      throw _handleError(error, errorParser ?? errorGeneralParser);
    }
  }

  Future<dynamic> _getCacheIfSocketException(
    dynamic error,
    bool persistenceCache,
    String cacheHash,
  ) async {
    if (error is DioError &&
        error.error is SocketException &&
        persistenceCache) {
      return await _getFromPersistenceCache(cacheHash);
    }
    return null;
  }

  String _handleError(dynamic exception,
      String Function(dynamic body, int statusCode) errorParser) {
    final Response<dynamic> response = exception?.response;
    dynamic responseBody;
    String error = defaultErrorMessage();
    final statusCode = response?.statusCode;
    if (exception is DioError) {
      if (exception.error is SocketException) {
        throw NetworkApiException(
          networkErrorMessage(),
          null,
          defaultErrorMessage(),
        );
      }
      if (exception.type == DioErrorType.connectTimeout) {
        throw NetworkApiException(
          connectionTimeOutMessage?.call(),
          response,
          defaultErrorMessage(),
        );
      }
      if (exception.type == DioErrorType.receiveTimeout) {
        throw NetworkApiException(
          receivingTimeOutMessage?.call(),
          response,
          defaultErrorMessage(),
        );
      }
      if (exception.type == DioErrorType.sendTimeout) {
        throw NetworkApiException(
          sendingTimeOutMessage?.call(),
          response,
          defaultErrorMessage(),
        );
      }
      try {
        responseBody = response?.data;
        error = errorParser(responseBody, statusCode) ?? defaultErrorMessage();
      } catch (e) {
        throw NetworkApiException(error, response, defaultErrorMessage());
      }
    }

    switch (response.statusCode) {
      // case 401:
      //   throw Exception('Error : Your Token Is Expired-$statusCode');
      //   break;
      //Todo handle when Token Expired 401
      default:
        throw NetworkApiException(error, response, defaultErrorMessage());
    }
  }
}

class _ResponseWithDataSource {
  final Response response;
  final DataSource dataSource;

  _ResponseWithDataSource({
    @required this.response,
    this.dataSource = DataSource.internet,
  });
}
