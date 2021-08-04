import 'package:api_manger/api_manger.dart';
import 'package:api_manger/src/extensions/extensions.dart';
import 'package:api_manger/src/utils/typedef.dart';
import 'package:api_manger/src/widgets/error_widget_holder.dart';
import 'package:api_manger/src/widgets/no_data_holder.dart';
import 'package:api_manger/src/widgets/show_progress.dart';
import 'package:flutter/material.dart';

class ResponseApiBuilder<T> extends StatelessWidget {
  final ApiReq<T> future;
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
  final ValueNotifier<bool> updateNotifier = ValueNotifier<bool>(false);

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
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      updateNotifier.value = !updateNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: updateNotifier,
        builder: (BuildContext context, bool value, _) {
          //to call _future one time
          final Future<ResponseApi<T>> _future = future();

          return FutureBuilder<ResponseApi<T>>(
              key: ValueKey<Future<ResponseApi<T>>>(_future),
              future: _future,
              builder: (BuildContext context,
                  AsyncSnapshot<ResponseApi<T>> snapshot) {
                final T data = snapshot?.data?.data ?? defaultData;
                final bool isDone = snapshot.isDoneX;
                final bool isLoading = !isDone;

                if (snapshot.hasErrorX && apiManager != null) {
                  apiManager.addRefreshListener(_refresh);
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _getWidget(
                    context: context,
                    data: data,
                    snapshot: snapshot,
                    isDone: isDone,
                    isLoading: isLoading,
                  ),
                );
              });
        });
  }

  Widget _getWidget(
      {BuildContext context,
      AsyncSnapshot<ResponseApi<T>> snapshot,
      bool isDone,
      bool isLoading,
      T data}) {
    if (snapshot.hasErrorX) {
      return errorWidgetHolder(
        context,
        snapshot.errorX,
        _refresh,
        retryMessage: retryMessage,
        errorBuilder: errorBuilder,
      );
    }

    if (apiManager != null) {
      apiManager.removeRefreshListener(_refresh);
    }

    if (isDone && snapshot.isNoData(noDataChecker)) {
      if (noDataBuilder == null) {
        return noDataWidgetHolder(noDataMessage);
      }
      return noDataBuilder(context, _refresh);
    }

    if (isLoading) {
      if (dataAndLoadingBuilder != null) {
        return dataAndLoadingBuilder(context, data, !isDone, _refresh);
      }
      return loadingBuilder(context);
    }

    if (snapshot.isNoData(noDataChecker)) {
      if (noDataBuilder == null) {
        return noDataWidgetHolder(noDataMessage);
      }
      return noDataBuilder(context, _refresh);
    }

    if (dataAndLoadingBuilder != null) {
      return dataAndLoadingBuilder(context, data, !isDone, _refresh);
    }

    return dataBuilder(context, data, _refresh);
  }
}
