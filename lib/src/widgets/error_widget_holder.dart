import 'package:api_manger/src/extensions/extensions.dart';
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
      children: <Widget>[
        const SizedBox(height: 4),
        Text(
          error,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        ElevatedButton(
          onPressed: () => refresh(),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(
                Theme.of(context).primaryColor),
          ),
          child: Text(
            retryMessage,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
      ],
    ).setCenter();
