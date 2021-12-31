import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dio_plus/flutter_dio_plus.dart';
import 'package:flutter_dio_plus/src/extensions/extensions.dart';

class ShowProgress extends StatelessWidget {
  const ShowProgress({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      // tryDo to avoid exception if Platform is web
      // Unsupported operation: Platform._operatingSystem
      child: tryDo(() => Platform.isIOS, orElse: (_, __) => false)
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
