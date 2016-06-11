part of scribe;

class ConsoleBackend implements LoggingBackend {
  IOSink outputSink;
  bool _nonBlocking;

  ConsoleBackend({bool nonBlocking: true, IOSink outputSink: null}) {
    _nonBlocking = nonBlocking;
    this.outputSink = outputSink;
  }


  Future start() async {
    if (outputSink == null) {
      if (_nonBlocking) {
        outputSink = stdout.nonBlocking;
      } else {
        outputSink = stdout;
      }
    }
  }

  void log(LogRecord record) {
    outputSink?.writeln("$record");
  }
}