import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:api_manger/src/api_util.dart';
import 'package:api_manger/src/base_cache_api_db.dart';
import 'package:api_manger/src/future_queue.dart';
import 'package:api_manger/src/network_api_exception.dart';
import 'package:api_manger/src/response_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

// Must be top-level function
dynamic _parseAndDecode(String response) {
  return jsonDecode(response);
}

Future<dynamic> _parseJsonCompute(String text) {
  return compute(_parseAndDecode, text);
}

class ApiManager {
  DateTime _firstCallTime;

  ApiManager(
    this._dio, {
    @required this.errorGeneralParser,
    @required this.apiCacheDB,
    @required this.getAuthHeader,
    @required this.getDefaultHeader,
    @required this.defaultErrorMessage,
    @required this.networkErrorMessage,
    this.isDevelopment = false,

    /// if response body Length > largeResponseLength package will parse response in another isolate(Thread)
    /// may take much time but it will improve rendering performance
    int largeResponseLength = 100000,
    this.onNetworkChanged,
  }) {
    _firstCallTime = DateTime.now();
    if (isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        logPrint: (object) {
          if (object is FormData) {
            print('fields: ${object.fields}');
            print('files: ${object?.files?.map(
              (e) => MapEntry(e?.key, e?.value?.filename),
            )}');
          }
          print(object);
        },
      ));
    }

    (_dio.transformer as DefaultTransformer).jsonDecodeCallback = (text) {
      if (text.length > largeResponseLength) return _parseJsonCompute(text);
      return _parseAndDecode(text);
    };

    Connectivity()
        .onConnectivityChanged
        .distinct()
        .listen((ConnectivityResult connectivityResult) {
      // to ignore onNetworkChanged in firstCall
      if (DateTime.now().isAfter(
        _firstCallTime.add(const Duration(seconds: 2)),
      )) {
        final bool _connected = connectivityResult != ConnectivityResult.none;
        if (onNetworkChanged != null)
          onNetworkChanged(_connected, connectivityResult);
      }
    });
  }

  final Dio _dio;

  /// if true we will print some information to know what happens
  final bool isDevelopment;

  /// used to make persistenceCache
  final BaseApiCacheDb apiCacheDB;

  ///send when auth=true
  final FutureOr<Map<String, String>> Function() getAuthHeader;

  ///use it when u need to send header Like [accept language]
  final FutureOr<Map<String, String>> Function() getDefaultHeader;

  /// return when errorGeneralParser or errorParser return null
  final String Function() defaultErrorMessage;

  /// return when SocketException
  final String Function() networkErrorMessage;

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
    Future<Response<dynamic>> Function() request,
    dynamic Function(dynamic body) editBody,
    T Function(dynamic body) parserFunction,
  }) async {
    try {
      final response = await request();
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e, stacktrace) {
      if (isDevelopment && (e is! NetworkApiException)) {
        print('ApiManger: $e \n$stacktrace');
      }
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
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
      return responseFromRawJson(await apiCacheDB?.get(hash));
    } catch (e, stacktrace) {
      if (isDevelopment)
        print('ApiManger: _getFromPersistenceCache=> $e \n$stacktrace');

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
      await apiCacheDB?.add(
        hash,
        responseToRawJson(res),
      );
    }
  }

  String _getCacheHash(String url, String method, Map<String, String> headers,
      {dynamic body}) {
    final allPram = '$url+ $method+ $headers+ $body';
    var hashedStr =
        base64.encode(utf8.encode(allPram)).split('').toSet().join('');
    var hashedUrl = base64.encode(utf8.encode(url)).split('').toSet().join('');
    return '$hashedUrl+ $hashedStr';
  }

  Future<Response<dynamic>> _sendRequestImpl(
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
        if (dataFromCache != null) return dataFromCache;
      }

      Response<dynamic> _res;
      if (queue) {
        _res = await ApiFutureQueue().run(
          () => _dio.request(
            url,
            options: Options(
              headers: _headers,
              method: method,
            ),
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
      return _res;
    } catch (error) {
      final dynamic dataFromCache = await _getCacheIfSocketException(
        error,
        persistenceCache,
        cacheHash,
      );
      if (dataFromCache != null) return dataFromCache;

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
            networkErrorMessage(), null, defaultErrorMessage());
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
