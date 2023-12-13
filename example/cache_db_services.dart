import 'package:flutter_dio_plus/flutter_dio_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheDbServices implements BaseApiCacheDb {
  Box _box;
  final String boxName = 'CACHE_DB';

  Future<void> init() async {
    if (_box != null) return;

    await Hive.initFlutter();

    _box = await Hive.openBox(boxName);
  }

  Box box() {
    if (_box == null) {
      throw Exception(
          'You should call init() first hint: CacheDbServices()..init()');
    }
    return _box;
  }

  @override
  Future<void> add(String hash, dynamic data) async {
    await init();
    await box().put(hash, data);
  }

  @override
  T get<T>(String hash) {
    return box().get(hash) as T;
  }

  @override
  Map<String, dynamic> getAllEntries() {
    return Map<String, dynamic>.from(box().toMap());
  }

  @override
  Iterable<dynamic> getAllCaches() {
    return box().values;
  }

  @override
  Iterable<String> getAllKeys() {
    return box().keys.map((e) => e.toString());
  }

  @override
  Future<void> deleteAll() async {
    await init();
    await box().clear();
  }

  @override
  Future<void> delete(String hash) async {
    await init();
    await _box.delete(hash);
  }

  @override
  Future<void> close() => Hive.close();
}
