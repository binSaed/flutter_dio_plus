import 'package:flutter/widgets.dart';
import 'package:flutter_dio_plus/src/widgets/widgets.dart';

extension ResponseApiBuilderStateX on GlobalKey<ResponseApiBuilderState> {
  void refresh() => currentState?.refresh();
}
