import 'package:api_manger/src/response_api.dart';
import 'package:flutter/material.dart';

extension AsyncSnapshotResponseApiX<T> on AsyncSnapshot<ResponseApi<T>> {
  bool hasNoData() {
    return !(this?.hasData ?? false);
  }

  bool isNoData(bool Function(T body) noDataChecker) {
    return (hasNoData()) ||
        data.isNoData ||
        this?.data?.data == null ||
        ((noDataChecker ?? (_) => false)(this?.data?.data));
  }

  bool get isDoneX => connectionState == ConnectionState.done;

  bool get hasErrorX => hasError || (this?.data?.hasError ?? false);

  String get errorX => (error ?? this?.data?.error ?? '').toString();
}
