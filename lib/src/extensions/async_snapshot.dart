import 'package:flutter/material.dart';

extension AsyncSnapshotX<T> on AsyncSnapshot<T> {
  bool hasNoData() {
    return !(this?.hasData ?? false);
  }
}
