import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

extension Filex on File {
  String get name {
    if (this == null) return '';

    return path.basename(this?.path ?? '');
  }

  Future<MultipartFile> toMultipartFile() async {
    return await MultipartFile.fromFile(
      this?.path,
      filename: this?.name,
    );
  }
}
