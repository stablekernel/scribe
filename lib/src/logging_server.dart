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
  Completer _stopCompleter;
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
    _loggingIsolate = await Isolate.spawn(logEntryPoint, [fromLoggingIsolateReceivePort.sendPort, _backends], paused: true);
    _loggingIsolate.setErrorsFatal(false);
    _loggingIsolate.addErrorListener(fromLoggingIsolateReceivePort.sendPort);
    _loggingIsolate.resume(_loggingIsolate.pauseCapability);

    var launchCompleter = new Completer();
    fromLoggingIsolateReceivePort.listen((msg) {
      if (msg is SendPort) {
        _destinationPort = msg;
        launchCompleter.complete();
        launchCompleter = null;
      } else if (msg is List) {
        _errorStreamController.addError(msg.first, new StackTrace.fromString(msg.last));

        if (launchCompleter != null) {
          launchCompleter.completeError(msg.first, new StackTrace.fromString(msg.last));
          fromLoggingIsolateReceivePort.close();
        }
      } else if (msg == "stopAck") {
        _stopCompleter.complete();
        _stopCompleter = null;
        fromLoggingIsolateReceivePort.close();
      }
    });

    await launchCompleter.future;
  }

  /// Stops this logging server.
  ///
  /// Kills the isolate running the log server.
  Future stop() async {
    _stopCompleter = new Completer();
    _destinationPort.send("stop");
    await _stopCompleter.future;

    if (_errorStreamController.hasListener) {
      await _errorStreamController.close();
    }
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

  await Future.wait(backends.map((b) => b.start()), eagerError: true);

  var fromListenerReceivePort = new ReceivePort();
  fromListenerReceivePort.listen((message) {
    if (message == "stop") {
      Future.wait(backends.map((b) => b.stop())).then((_) {
        fromListenerReceivePort.close();
        port.send("stopAck");
      });
    } else {
      backends.forEach((b) => b.log(message));
    }
  });

  port.send(fromListenerReceivePort.sendPort);
}