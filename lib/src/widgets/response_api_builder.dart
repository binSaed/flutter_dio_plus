import 'package:api_manger/api_manger.dart';
import 'package:api_manger/src/extensions/extensions.dart';
import 'package:api_manger/src/widgets/show_progress.dart';
import 'package:flutter/material.dart';

typedef NoDataBuilder = Widget Function(BuildContext context);
typedef LoadingBuilder = Widget Function(BuildContext context);
typedef ErrorBuilder = Widget Function(BuildContext context, String error);
typedef DataBuilder<T> = Widget Function(BuildContext context, T data);
typedef DataAndLoadingBuilder<T> = Widget Function(
    BuildContext context, T data, bool loading);

class ResponseApiBuilder<T> extends StatelessWidget {
  final Future<ResponseApi<T>> future;
  final DataBuilder<T> data;
  final DataAndLoadingBuilder<T> dataAndLoading;
  final NoDataBuilder noData;
  final String noDataMessage;
  final LoadingBuilder loading;
  final ErrorBuilder error;
  final bool Function(T body) noDataChecker;
  final T defaultData;

  const ResponseApiBuilder({
    Key key,
    @required this.future,
    this.data,
    this.dataAndLoading,
    this.noData,
    this.loading,
    this.error,
    this.noDataChecker,
    this.defaultData,
    this.noDataMessage = 'No Data',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResponseApi<T>>(
        future: future,
        builder:
            (BuildContext context, AsyncSnapshot<ResponseApi<T>> snapshot) {
          final T list = snapshot?.data?.data ?? defaultData;
          final bool isDone = snapshot.connectionState == ConnectionState.done;
          if (dataAndLoading != null) {
            return dataAndLoading(context, list, !isDone);
          }
          if (!isDone) {
            if (loading != null) {
              return loading(context);
            }
            return ShowProgress().setCenter();
          }

          if (snapshot.hasError || (snapshot?.data?.hasError ?? false)) {
            final String _error =
                (snapshot.error ?? snapshot?.data?.error ?? '').toString();

            if (error != null) {
              return error(context, _error);
            }

            return Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[600],
              ),
            ).setCenter();
          }

          if ((snapshot.hasNoData()) ||
              snapshot.data.isNoData ||
              snapshot?.data?.data == null ||
              ((noDataChecker ?? (_) => false)(snapshot?.data?.data))) {
            if (noData != null) {
              return noData(context);
            }

            return Text(noDataMessage).setCenter();
          }

          return data(context, list);
        });
  }
}
