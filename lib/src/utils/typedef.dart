import 'package:api_manger/src/response_api.dart';
import 'package:flutter/material.dart';

typedef Refresh = void Function();

typedef ApiReq<T> = Future<ResponseApi<T>> Function();
typedef NoDataBuilder = Widget Function(BuildContext context, Refresh refresh);
typedef LoadingBuilder = Widget Function(BuildContext context);
typedef ErrorBuilder = Widget Function(
    BuildContext context, String error, Refresh refresh);
typedef DataBuilder<T> = Widget Function(
    BuildContext context, T data, Refresh refresh);
typedef DataAndLoadingBuilder<T> = Widget Function(
    BuildContext context, T data, bool loading, Refresh refresh);

typedef NoDataChecker<T> = bool Function(T body);
