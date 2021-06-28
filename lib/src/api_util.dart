import 'dart:convert' as converter;

import 'package:dio/dio.dart';

Response<dynamic> responseFromRawJson(dynamic rawJson) {
  if (rawJson == null) return null;
  final dynamic json = converter.json.decode(rawJson);
  return responseFromJson(json);
}

Response<dynamic> responseFromJson(dynamic json) {
  final Response<dynamic> response = Response<dynamic>(
    requestOptions: RequestOptions(
        path: json['path'], method: json['method'], headers: json['headers']),
  );
  response.data = json['data'];
  response.extra = json['extra'];
  response.statusCode = json['statusCode'];
  response.isRedirect = json['isRedirect'];

  return response;
}

String responseToRawJson(Response<dynamic> response) {
  return converter.json.encode(responseToJson(response));
}

Map<String, dynamic> responseToJson(Response<dynamic> response) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['data'] = response.data;
  data['headers'] = response.requestOptions.headers;
  data['extra'] = response.extra;
  data['statusCode'] = response.statusCode;
  data['isRedirect'] = response.isRedirect;
  data['path'] = response.requestOptions.path;
  data['method'] = response.requestOptions.method;

  return data;
}
