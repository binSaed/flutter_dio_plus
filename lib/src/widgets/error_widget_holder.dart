import 'package:api_manger/src/utils/typedef.dart';
import 'package:flutter/material.dart';

Widget errorWidgetHolder(
  BuildContext context,
  String error,
  Refresh refresh, {
  @required String retryMessage,
}) =>
    Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          error,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => refresh(),
          child: Text(
            retryMessage,
            textAlign: TextAlign.center,
          ),
        )
      ],
    );
