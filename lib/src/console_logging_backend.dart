part of scribe;

/// Logs messages to [stdout] or some other [IOSink].
class ConsoleBackend implements LoggingBackend {
  /// Constructor for [ConsoleBackend].
  ///
  /// By default, [nonBlocking] is true. This will use [stdout]'s [nonBlocking].
  ConsoleBackend({bool nonBlocking: true}) {
    _nonBlocking = nonBlocking;
  }

  IOSink _outputSink;
  bool _nonBlocking;

  Future start() async {
    if (_nonBlocking) {
      _outputSink = stdout.nonBlocking;
    } else {
      _outputSink = stdout;
    }
  }

  Future stop() async {
    await _outputSink?.close();
    _outputSink = null;
  }

  void log(LogRecord record) {
    _outputSink?.writeln("$record");
  }
}
