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
  StreamController<dynamic> _errorStreamController = new StreamController();
  Stream<dynamic> get errorStream => _errorStreamController.stream;

  /// Creates a new [LoggingTarget] for this logging server.
  ///
  /// In order for a [LoggingServer] to receive log messages, you must [LoggingTarget.bind] the returned
  /// instance to a [Logger].
  LoggingTarget getNewTarget() {
    return new LoggingTarget._(_destinationPort);
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

    var completer = new Completer();
    fromLoggingIsolateReceivePort.listen((msg) {
      if (msg is SendPort) {
        _destinationPort = msg;
        completer.complete();
        completer = null;
      } else {
        _errorStreamController.add(msg);
        completer?.completeError(msg);
      }
    });

    await completer.future;
  }

  /// Stops this logging server.
  ///
  /// Kills the isolate running the log server.
  void stop() {
    _loggingIsolate?.kill();
  }
}

class SafeLogRecord {
  final Level level;
  final String message;
  final String loggerName;
  final DateTime time;
  final String stackTrace;
  final String error;

  SafeLogRecord(this.level, this.message, this.loggerName, this.time, this.stackTrace, this.error);

  String toString() => "[$level] $time $loggerName: $message${error != null ? " ${_escapeNewlines(error)}" : ""}${stackTrace != null ? " ${_escapeNewlines(stackTrace)}" : ""}";

  String _escapeNewlines(String str) {
    return str.replaceAll("\n", "\\n");
  }
}

Future logEntryPoint(List<dynamic> arguments) async {
  SendPort port = arguments[0];
  List<LoggingBackend> backends = arguments[1];

  try {
    await Future.wait(backends.map((b) => b.start()), eagerError: true);
  } catch (error) {
    port.send(error);
    return;
  }

  var fromListenerReceivePort = new ReceivePort();
  fromListenerReceivePort.listen((record) {
    try {
      backends.forEach((b) => b.log(record));
    } catch (error) {
      port.send(error);
    }
  });

  port.send(fromListenerReceivePort.sendPort);
}