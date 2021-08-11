import 'package:flutter/material.dart';

extension WidgetX on Widget {
  Widget setCenter() {
    return Center(
      child: this,
    );
  }

  Widget setWidth(double width) {
    return SizedBox(width: width, child: this);
  }

  Widget setHeight(double height) {
    return SizedBox(height: height, child: this);
  }
}
