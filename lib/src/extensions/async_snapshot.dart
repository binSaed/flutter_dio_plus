import 'package:api_manger/src/response_api.dart';
import 'package:flutter/material.dart';

extension AsyncSnapshotResponseApiX<T> on AsyncSnapshot<ResponseApi<T>> {
  bool hasNoData() {
    return !(this?.hasData ?? false);
  }

  bool isNoData(bool Function(T body) noDataChecker) {
    if (hasNoData()) return true;

    if (data.isNoData) return true;

    final _data = this?.data?.data;

    if (_data == null) return true;

    if (_data.runtimeType.toString().startsWith('List') &&
        (_data as List).isEmpty) return true;

    if ((noDataChecker ?? (_) => false)(_data)) return true;

    return false;
  }

  bool get isDoneX => connectionState == ConnectionState.done;

  bool get hasErrorX => hasError || (this?.data?.hasError ?? false);

  String get errorX => (error ?? this?.data?.error ?? '').toString();
}
