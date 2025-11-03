import 'package:fpdart/fpdart.dart';

/// Safely execute an async task, catching errors and converting to TaskEither
TaskEither<String, T> safeTask<T>(Future<T> Function() task) {
  return TaskEither.tryCatch(task, (error, _) => error.toString());
}

/// Safely execute a synchronous task, catching errors and converting to TaskEither
TaskEither<String, T> safe<T>(T Function() task) {
  return TaskEither.fromEither(
    Either.tryCatch(task, (error, _) => error.toString()),
  );
}
