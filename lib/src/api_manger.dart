import 'dart:collection';
import 'dart:io';

import 'package:api_manger/src/api_util.dart';
import 'package:api_manger/src/base_cache_api_db.dart';
import 'package:api_manger/src/future_queue.dart';
import 'package:api_manger/src/network_api_exception.dart';
import 'package:api_manger/src/response_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class _RefreshListenerEntry extends LinkedListEntry<_RefreshListenerEntry> {
  _RefreshListenerEntry(this.listener);

  final VoidCallback listener;
}

class ApiManager {
  ApiManager(
    this._dio, {
    @required this.errorGeneralParser,
    @required this.apiCacheDB,
    @required this.getUserToken,
    @required this.defaultErrorMessage,
    @required this.networkErrorMessage,
    this.isDevelopment = false,
    this.onNetworkChanged,
  }) {
    if (isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        logPrint: (Object object) =>
            debugPrint(object.toString(), wrapWidth: 600),
      ));
    }
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final bool _connected = result != ConnectivityResult.none;
      if (onNetworkChanged != null) onNetworkChanged(_connected);
      if (_connected) notifyRefreshListeners();
    });
  }

  final Dio _dio;

  /// if true we will print some information to know what happens
  final bool isDevelopment;

  /// used to make persistenceCache
  final BaseApiCacheDb apiCacheDB;

  ///send as bearer token when auth==true
  final String Function() getUserToken;

  /// return when SocketException
  final String Function() defaultErrorMessage;

  /// return when SocketException
  final String Function() networkErrorMessage;

  /// if ur backend used the same error structure
  /// u need to define how to parsing it
  /// also, u can override it in every request
  final String Function(dynamic body) errorGeneralParser;

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

  void notifyRefreshListeners() {
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

  Map<String, String> headersWithBearerToken(String token,
      {Map<String, String> otherHeaders = const <String, String>{}}) {
    return <String, String>{'Authorization': 'Bearer $token', ...otherHeaders};
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
    String Function(dynamic body) errorParser,
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
        parse(body, parserFunction),
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
    String Function(dynamic body) errorParser,
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
        parse(body, parserFunction),
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
    String Function(dynamic body) errorParser,
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
        parse(body, parserFunction),
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
    String Function(dynamic body) errorParser,
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
        parse(body, parserFunction),
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
    String Function(dynamic body) errorParser,
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
        parse(body, parserFunction),
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
    String Function(dynamic body) errorParser,
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
          parse(body, parserFunction), response, defaultErrorMessage());
    } catch (e) {
      return ResponseApi<T>.error(e, e?.response, defaultErrorMessage());
    }
  }

  T parse<T>(dynamic body, T Function(dynamic body) parserFunction) {
    if (parserFunction == null) {
      return body;
    }

    try {
      return parserFunction(body);
    } catch (e) {
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

  String getCacheHash(String url, String method, Map<String, String> headers,
      {dynamic body}) {
    return '$url+ $method+ $headers+ $body'.toLowerCase();
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
    String Function(dynamic body) errorParser,
  }) async {
    final Map<String, String> _headers = <String, String>{
      ...headers,
      ...auth ? _tokenHeader() : <String, String>{}
    };
    final String cacheHash = getCacheHash(url, method, _headers, body: body);
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

  Map<String, String> _tokenHeader() {
    final String token = getUserToken();
    final String bearerToken = 'Bearer $token';
    return <String, String>{'Authorization': bearerToken};
  }

  String _handleError(
      dynamic exception, String Function(dynamic body) errorParser) {
    final Response<dynamic> response = exception?.response;
    dynamic responseBody;
    String error = defaultErrorMessage();

    if (exception is DioError) {
      if (exception.error is SocketException) {
        throw NetworkApiException(
            networkErrorMessage(), null, defaultErrorMessage());
      }
      try {
        responseBody = response?.data;
        error = errorParser(responseBody) ?? defaultErrorMessage();
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
