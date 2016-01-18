part of scribe;

class ConsoleBackend implements LoggingBackend {
  IOSink outputSink;
  bool _nonBlocking;

  ConsoleBackend({bool nonBlocking: true}) {
    _nonBlocking = nonBlocking;
  }

  Future start() async {
    if (_nonBlocking) {
      outputSink = stdout.nonBlocking;
    } else {
      outputSink = stdout;
    }
  }

  void log(LogRecord record) {
    outputSink?.writeln("$record");
  }
}
