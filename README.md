
# flutter_dio_plus

![Pub Version](https://img.shields.io/pub/v/flutter_dio_plus?color=1&label=flutter_dio_plus)
![GitHub repo size](https://img.shields.io/github/repo-size/AbdOoSaed/flutter_dio_plus)
![issues-raw](https://img.shields.io/github/issues-raw/AbdOoSaed/flutter_dio_plus)
![license](https://img.shields.io/github/license/AbdOoSaed/flutter_dio_plus)
![last-commit](https://img.shields.io/github/last-commit/AbdOoSaed/flutter_dio_plus)
![stars](https://img.shields.io/github/stars/AbdOoSaed/flutter_dio_plus?style=social)

[![support](https://img.shields.io/badge/platform-flutter%7Cflutter%20web%7Cdart%20vm-ff69b4.svg?style=flat-square)](https://github.com/AbdOoSaed/flutter_dio_plus)

<p align="center">
<img src="https://user-images.githubusercontent.com/33700292/157306851-25e6a9d7-57dc-4d94-89d0-e94c756c23e5.png" alt="Dio plus Logo"  style="display: block;margin-left: auto;margin-right: auto;width: 22%;">
</p>



A flutter package to API handling like a super boss 😎.


## Features

- Simple to use
- Offline support "Memory and Persistence cache"
- Response Wrapper to handle error and data response.
- Logs network calls in a pretty, easy to read format
- Use compute when parsing large JSON to enhance performance
- Customized error and loading messages
- Widget to show error,loading and data handling with retry feature.



## Installation

Install by pubspec.yaml
```yaml
  dio: ^4.0.4
  flutter_dio_plus: ^0.0.1
```

## Usage/Examples

Import flutter_dio_plus.dart

```dart
import 'package:flutter_dio_plus/flutter_dio_plus.dart';
```

instantiate DioPlus

```dart
  DioPlus _dioPlus = DioPlus(
  Dio(
    BaseOptions(
      baseUrl: "Your Base Url here",
    ),
  ),

  /// Provider your cache database
  persistenceCacheDB: _cacheDb,

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

  /// to show logs in debug only
  isDevelopment: isDebug,
);
```

send request

```dart
    final ResponseApi<UserModel> userModel = await _dioPlus.get<UserModel>(
      "/path",
      (body) => UserModel.fromJson(body),
      queryParameters: {"id": "1"},
      auth: false,
      // Send auth headers in this request or not.
      memoryCache: true,
      // Save response in memory Cache
      persistenceCache: true,
      // Save response in persistence Cache
      queue: false, // Wait for the same request to end to send another
    );
```

Check response status

```flutter
  if (userModel.isSuccess) {
    // run some code
  } else if (userModel.hasError) {
    // Show error
  } else if (userModel.isNoData) {
    // Show there is no data
  }
```


## Used By

This project is used by the following companies:

- [Happy Trip](https://happytbooking.com/)
- [iStoria](https://istoria.app)


## License

[MIT](https://choosealicense.com/licenses/mit/)

