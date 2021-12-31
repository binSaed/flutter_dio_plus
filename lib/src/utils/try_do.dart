/// try to run a function that may be throws an exception
/// by default if an exception is thrown null value will be returned
/// also u have the ability to handle exceptions and return a custom value
/// Ex.  print(tryDo(() => DateTime.parse('')));
/// Credit to https://gist.github.com/AbdOoSaed/7edd858bb6e2cc0550b9be205402d912
T tryDo<T>(
  T Function() function, {
  T whenNull,
  T Function(dynamic exception, StackTrace stacktrace) orElse,
}) {
  try {
    return function?.call() ?? whenNull;
  } catch (e, stacktrace) {
    return orElse?.call(e, stacktrace);
  }
}
