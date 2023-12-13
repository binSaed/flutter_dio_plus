import 'package:dio/dio.dart';
import 'package:flutter_dio_plus/flutter_dio_plus.dart';

import 'cache_db_services.dart';
import 'user_model.dart';

void main() async {
  final CacheDbServices _cacheDbServices = CacheDbServices();

  DioPlus _dioPlus = DioPlus(
    Dio(
      BaseOptions(
        baseUrl: "Your Base Url here",
      ),
    ),

    /// Provider your cache database
    persistenceCacheDB: _cacheDbServices,

    /// Add your default error message
    defaultErrorMessage: () => 'error',

    /// Add your Socket connection error message
    networkErrorMessage: () => 'network_error_message',

    /// Add your retry button text
    retryBtnMessage: () => 'try_again',

    /// Add no data message
    noDataMessage: () => 'no_data',

    /// Add your connection timeOut text
    connectionTimeOutMessage: () => 'connection_time_out_message',

    /// Add your receiving timeOut text
    receivingTimeOutMessage: () => 'receiving_time_out_message',

    /// Add your sending timeOut text
    sendingTimeOutMessage: () => 'sending_time_out_message',

    /// General parser for errors in response
    errorGeneralParser: (dynamic body, statusCode) {
      final errorMessage = body["error"];
      return errorMessage;
    },

    /// Default headers
    getDefaultHeader: () {
      return {
        'Accept-Language': "en",
      };
    },

    /// Header added to request when auth in request is true
    getAuthHeader: () {
      return {
        'Authorization': 'Bearer TOKEN',
      };
    },

    /// Fire when internet connection changes
    onNetworkChanged: (bool connected, _) {
      // show toast to inform user that internet connection lost/restore.
    },
  );

  final ResponseApi<UserModel> userModel = await _dioPlus.get<UserModel>(
    "Path",
    (body) => UserModel.fromJson(body),
    queryParameters: {"id": "1"},
    auth: false,    // Send auth headers in this request or not.
    memoryCache: true,    // Save response in memory Cache
    persistenceCache: true,    // Save response in persistence Cache
    queue: false, // Wait for the same request to end to send another
  );
}
