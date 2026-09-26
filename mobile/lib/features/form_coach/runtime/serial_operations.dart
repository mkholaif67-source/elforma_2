/// Keep native camera transitions ordered, including calls made while an
/// earlier transition is awaiting the platform. Failures do not poison the tail.
class SerialOperations {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool get busy => _pending > 0;
  Future<void> get settled => _tail;

  Future<T> run<T>(Future<T> Function() operation) {
    _pending++;
    final result =
        _tail.then((_) => operation()).whenComplete(() => _pending--);
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
