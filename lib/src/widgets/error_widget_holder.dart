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
        SizedBox(height: 2),
        Text(
          error,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
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
        ), SizedBox(height: 2),
      ],
    );
