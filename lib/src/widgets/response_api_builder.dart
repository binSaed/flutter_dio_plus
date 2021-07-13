import 'package:api_manger/api_manger.dart';
import 'package:api_manger/src/extensions/extensions.dart';
import 'package:api_manger/src/utils/typedef.dart';
import 'package:api_manger/src/widgets/error_widget_holder.dart';
import 'package:api_manger/src/widgets/no_data_holder.dart';
import 'package:api_manger/src/widgets/show_progress.dart';
import 'package:flutter/material.dart';

class ResponseApiBuilder<T> extends StatelessWidget {
  final ApiReq future;
  final T defaultData;
  final DataBuilder<T> dataBuilder;
  final DataAndLoadingBuilder<T> dataAndLoadingBuilder;
  final NoDataBuilder noDataBuilder;
  final LoadingBuilder loadingBuilder;
  final ErrorBuilder errorBuilder;
  final NoDataChecker<T> noDataChecker;
  final String noDataMessage;
  final String retryMessage;

  /// required if u need to retry failed requests when internet comeback
  /// if apiManager!=null auto refresh error requests will run
  final ApiManager apiManager;
  final ValueNotifier<bool> updateNotifier = ValueNotifier(false);

  ResponseApiBuilder({
    Key key,
    @required this.future,
    this.apiManager,
    this.dataBuilder,
    this.dataAndLoadingBuilder,
    this.noDataBuilder,
    this.loadingBuilder = loadingWidgetHolder,
    this.errorBuilder,
    this.noDataChecker,
    this.defaultData,
    this.noDataMessage = 'No Data',
    this.retryMessage = 'Try again',
  }) : super(key: key);

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateNotifier.value = !updateNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: updateNotifier,
        builder: (context, value, _) {
          return FutureBuilder<ResponseApi<T>>(
              key: UniqueKey(),
              future: future(),
              builder: (BuildContext context,
                  AsyncSnapshot<ResponseApi<T>> snapshot) {
                final T list = snapshot?.data?.data ?? defaultData;
                final bool isDone = snapshot.isDoneX;

                if (snapshot.hasErrorX && apiManager != null) {
                  apiManager.addRefreshListener(_refresh);
                }

                if (snapshot.hasErrorX) {
                  final String _error = snapshot.errorX;
                  if (errorBuilder != null) {
                    errorBuilder(context, _error, _refresh);
                  }
                  return errorWidgetHolder(
                    context,
                    _error,
                    _refresh,
                    retryMessage: retryMessage,
                  );
                }
                apiManager.removeRefreshListener(_refresh);
                if (dataAndLoadingBuilder != null) {
                  return dataAndLoadingBuilder(
                      context, list, !isDone, _refresh);
                }

                if (!isDone) {
                  return loadingBuilder(context);
                }

                if (snapshot.isNoData(noDataChecker)) {
                  if (noDataBuilder == null) {
                    return noDataWidgetHolder(noDataMessage);
                  }
                  return noDataBuilder(context, _refresh);
                }

                return dataBuilder(context, list, _refresh);
              });
        });
  }
}
