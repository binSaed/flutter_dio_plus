/// you should implements this class to use ApiManager 'persistenceCache'
abstract class BaseApiCacheDb {
  Future<void> add(String key, dynamic data);

  T get<T>(String key);

  Iterable<dynamic> getAllCaches();

  Iterable<String> getAllKeys();

  Map<String, dynamic> getAllEntries();

  Future<void> deleteAll();

  Future<void> delete(String hash);

  Future<void> close();
}
