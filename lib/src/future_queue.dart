import 'dart:async';

mixin FutureQueue {
  /// Request [operation] to be run exclusively.
  ///
  /// Waits for all previously requested operations to complete,
  /// then runs the operation and completes the returned future with the
  /// result.
  /// All creds to https://stackoverflow.com/a/42091982/2608145
  Future<dynamic> _next = Future<dynamic>.value(null);

  Future<T> run<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _next.whenComplete(() {
      completer.complete(Future<T>.sync(operation));
    });
    return _next = completer.future;
  }
}

class ApiFutureQueue with FutureQueue {
  static final ApiFutureQueue _singleton = ApiFutureQueue._internal();

  factory ApiFutureQueue() => _singleton;

  ApiFutureQueue._internal();
}
