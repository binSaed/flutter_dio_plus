import 'dart:io';

import 'package:api_manger/src/extensions/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ShowProgress extends StatelessWidget {
  const ShowProgress({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Platform.isIOS
          ? const CupertinoActivityIndicator()
          : CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
    );
  }
}

Widget loadingWidgetHolder(_) => const ShowProgress().setCenter();
