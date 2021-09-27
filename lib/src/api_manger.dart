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

class _RefreshListenerEntry extends LinkedListEntry<_RefreshListenerEntry> {
  _RefreshListenerEntry(this.listener);

  final VoidCallback listener;
}

// Must be top-level function
dynamic _parseAndDecode(String response) {
  return jsonDecode(response);
}

Future<dynamic> _parseJsonCompute(String text) {
  return compute(_parseAndDecode, text);
}

class ApiManager {
  bool _firstCall = true;

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
    if (isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
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

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final bool _connected = result != ConnectivityResult.none;
      if (_firstCall) {
        _firstCall = false;

        if (_connected) return;
      }

      if (onNetworkChanged != null) onNetworkChanged(_connected);
      if (_connected) _notifyRefreshListeners();
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

  /// return when SocketException
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
  final ValueChanged<bool> onNetworkChanged;

  /// used to save response in memory
  final Map<String, dynamic> _httpCaching = HashMap<String, dynamic>();

  /// used to retry failed ResponseApiBuilder requests when internet comeback
  final LinkedList<_RefreshListenerEntry> _refreshListeners =
      LinkedList<_RefreshListenerEntry>();

  void addRefreshListener(VoidCallback listener) {
    _refreshListeners.add(_RefreshListenerEntry(listener));
  }

  void removeRefreshListener(VoidCallback listener) {
    for (final _RefreshListenerEntry entry in _refreshListeners) {
      if (entry.listener == listener) {
        entry.unlink();
        return;
      }
    }
  }

  void _notifyRefreshListeners() {
    if (_refreshListeners.isEmpty) return;

    final List<_RefreshListenerEntry> localListeners =
        List<_RefreshListenerEntry>.from(_refreshListeners);

    for (final _RefreshListenerEntry entry in localListeners) {
      try {
        if (entry.list != null) entry.listener();
      } catch (exception, _) {
        if (isDevelopment) {
          print('ApiManger: notifyRefreshListeners=> $exception');
        }
      }
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
    try {
      final Response<dynamic> response = await _sendRequestImpl(
        url,
        auth: auth,
        headers: headers,
        body: postBody,
        queue: queue,
        onSendProgress: onSendProgress,
        method: 'POST',
        errorParser: errorParser,
      );
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e) {
      if (isDevelopment && (e is! NetworkApiException)) {
        print('ApiManger: $e');
      }
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
      );
    }
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
    try {
      final Response<dynamic> response = await _sendRequestImpl(
        url,
        auth: auth,
        headers: headers,
        body: dataBody,
        queue: queue,
        onSendProgress: onSendProgress,
        method: 'patch',
        errorParser: errorParser,
      );
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e) {
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
      );
    }
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
    try {
      final Response<dynamic> response = await _sendRequestImpl(
        url,
        auth: auth,
        headers: headers,
        body: dataBody,
        queue: queue,
        onSendProgress: onSendProgress,
        method: 'PUT',
        errorParser: errorParser,
      );
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e) {
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
      );
    }
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
    try {
      final Response<dynamic> response = await _sendRequestImpl(
        url,
        auth: auth,
        headers: headers,
        memoryCache: true,
        queue: queue,
        method: 'GET',
        errorParser: errorParser,
      );
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e) {
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
      );
    }
  }

  Future<ResponseApi<T>> get<T>(
    String url,
    T Function(dynamic body) parserFunction, {
    dynamic Function(dynamic body) editBody,
    Map<String, String> headers = const <String, String>{},
    bool auth = false,
    bool queue = false,
    bool memoryCache = false,
    bool persistenceCache = false,
    String Function(dynamic body, int statusCode) errorParser,
  }) async {
    try {
      final Response<dynamic> response = await _sendRequestImpl(
        url,
        auth: auth,
        headers: headers,
        queue: queue,
        memoryCache: memoryCache,
        persistenceCache: persistenceCache,
        method: 'GET',
        errorParser: errorParser,
      );
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
        _parse(body, parserFunction),
        response,
        defaultErrorMessage(),
      );
    } catch (e) {
      return ResponseApi<T>.error(
        e,
        e?.response,
        defaultErrorMessage(),
      );
    }
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
    try {
      final Response<dynamic> response = await _sendRequestImpl(url,
          auth: auth,
          headers: headers,
          queue: queue,
          body: dataBody,
          method: 'delete',
          errorParser: errorParser);
      dynamic body = response.data;
      if (editBody != null) {
        body = editBody(body);
      }
      return ResponseApi<T>.success(
          _parse(body, parserFunction), response, defaultErrorMessage());
    } catch (e) {
      return ResponseApi<T>.error(e, e?.response, defaultErrorMessage());
    }
  }

  T _parse<T>(dynamic body, T Function(dynamic body) parserFunction) {
    if (parserFunction == null) return body;

    try {
      return parserFunction(body);
    } catch (e) {
      if (e is FormatException || e is TypeError || e is NoSuchMethodError) {
        if (isDevelopment) print('ApiManger: parserFunction=> $e');

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
      return responseFromRawJson(await apiCacheDB.get(hash));
    } catch (e) {
      if (isDevelopment) print('ApiManger: _getFromPersistenceCache=> $e');

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
      await apiCacheDB.add(
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
      ...auth ? await getAuthHeader() : <String, String>{},
      ...await getDefaultHeader(),
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
          ),
        );
      } else {
        _res = await _dio.request(
          url,
          options: Options(headers: _headers, method: method),
          data: body,
          onSendProgress: onSendProgress,
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
    final statusCode = response.statusCode;
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
