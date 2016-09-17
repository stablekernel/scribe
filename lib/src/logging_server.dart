part of scribe;

/// An object that redirects log messages to different [LoggingBackend]s.
///
/// A [LoggingServer] runs on its own [Isolate] and maintains a list of [LoggingBackend]s. When log messages
/// are sent to a [LoggingServer] through its [LoggingTarget]s, the log message will be delivered to the logging
/// isolate and then sent to each [LoggingBackend]. Example:
///
///         var server = new LoggingServer([new ConsoleBackend()]);
///         server.getNewTarget().bind(new Logger("myLogger"));
///         await server.start();
///
class LoggingServer {
  /// Constructor for [LoggingServer].
  ///
  /// You must pass all [LoggingBackend]s to this constructor when instantiated. This server
  /// will send all log messages to each backend.
  LoggingServer(List<LoggingBackend> backends) {
    _backends = backends ?? [];
  }

  List<LoggingBackend> _backends;
  Isolate _loggingIsolate;
  SendPort _destinationPort;

  /// Creates a new [LoggingTarget] for this logging server.
  ///
  /// In order for a [LoggingServer] to receive log messages, you must [LoggingTarget.bind] the returned
  /// instance to a [Logger].
  LoggingTarget getNewTarget() {
    return new LoggingTarget(_destinationPort);
  }

  /// Starts this logging server.
  ///
  /// A logging server will not start receiving log messages until it has been started.
  Future start() async {
    if (_backends.isEmpty) {
      return;
    }

    var fromLoggingIsolateReceivePort = new ReceivePort();
    _loggingIsolate = await Isolate.spawn(logEntryPoint, [fromLoggingIsolateReceivePort.sendPort, _backends]);
    _destinationPort = await fromLoggingIsolateReceivePort.first;
  }

  /// Stops this logging server.
  ///
  /// Kills the isolate running the log server.
  void stop() {
    _loggingIsolate?.kill();
  }
}

class _SafeLogRecord implements LogRecord {
  final Level level;
  final String message;
  final String loggerName;
  final DateTime time;
  final StackTrace stackTrace;

  final Object object = null;
  final Zone zone = null;
  final Error error = null;
  final int sequenceNumber = 0;

  _SafeLogRecord(this.level, this.message, this.loggerName, this.time, this.stackTrace) {}

  String toString() => '[$level] $time $loggerName: $message';
}

Future logEntryPoint(List<dynamic> arguments) async {
  SendPort port = arguments[0];
  List<LoggingBackend> backends = arguments[1];

  await Future.wait(backends.map((b) => b.start()));

  var fromListenerReceivePort = new ReceivePort();
  fromListenerReceivePort.listen((record) {
    backends.forEach((b) => b.log(record));
  });

  port.send(fromListenerReceivePort.sendPort);
}

class LogListenerException implements Exception {
  LogListenerException(this.message);

  String message;
}
