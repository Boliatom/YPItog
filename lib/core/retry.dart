import 'api_exceptions.dart';

class RetryPolicy {
  const RetryPolicy({
    this.delays = const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
    ],
  });

  const RetryPolicy.none() : delays = const [];

  final List<Duration> delays;

  int get maxAttempts => delays.length + 1;

  Future<T> run<T>(Future<T> Function() action) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } on NetworkException {
        if (attempt >= delays.length) rethrow;
        await Future<void>.delayed(delays[attempt]);
        attempt++;
      }
    }
  }
}
