import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

extension FileX on File {
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

extension FilesX on List<File> {
  Future<List<MultipartFile>> toMultipart() async {
    final List<MultipartFile> multipartFiles = <MultipartFile>[];
    for (final File file in (this ?? <File>[])) {
      multipartFiles.add(await file.toMultipartFile());
    }

    return multipartFiles;
  }
}
