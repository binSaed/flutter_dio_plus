import 'package:flutter/material.dart';

extension WidgetX on Widget {
  Widget setCenter() {
    return Center(
      child: this,
    );
  }

  Widget setWidth(double width) {
    return Container(width: width, child: this);
  }

  Widget setHeight(double height) {
    return Container(height: height, child: this);
  }
}
