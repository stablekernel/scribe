// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.


part of scribe;

class LoggingServer {
  LoggingServer(List<LoggingBackend> backends) {
    _backends = backends ?? [];
  }

  List<LoggingBackend> _backends;
  Isolate _loggingIsolate;
  SendPort _destinationPort;

  LoggingTarget getNewTarget() {
    return new LoggingTarget(_destinationPort);
  }

  Future start() async {
    if (_backends.isEmpty) {
      return;
    }

    print("Starting logging server...");
    var fromLoggingIsolateReceivePort = new ReceivePort();
    fromLoggingIsolateReceivePort.listen((msg) {
      print("$msg");
    });
    print("Starting logging isolate...");
    try {
      _loggingIsolate = await Isolate.spawn(_logEntryPoint, [fromLoggingIsolateReceivePort.sendPort, _backends], paused: true, errorsAreFatal: true);
      print("Started paused isolate");
      _loggingIsolate.addErrorListener(fromLoggingIsolateReceivePort.sendPort);
      print("Resuming");
      _loggingIsolate.resume(_loggingIsolate.pauseCapability);
      print("resumed");
    } catch (e) {
      print("Logging isolate fialed to start: $e");
    }
    print("Waiting for logging isolate to respond...");
    _destinationPort = await fromLoggingIsolateReceivePort.first;
    print("Logging server started");
  }

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

  _SafeLogRecord(this.level, this.message, this.loggerName, this.time, this.stackTrace) {

  }

  String toString() => '[$level] $time $loggerName: $message';
}

Future _logEntryPoint(List<dynamic> arguments) async {
  print("... Logging isolate entered.");
  SendPort port = arguments[0];
  List<LoggingBackend> backends = arguments[1];

  await Future.wait(backends.map((b) => b.start()));

  var fromListenerReceivePort = new ReceivePort();
  fromListenerReceivePort.listen((record) {
    backends.forEach((b) => b.log(record));
  });

  print("Logging isolate responding...");
  port.send(fromListenerReceivePort.sendPort);
}

class LogListenerException implements Exception {
  LogListenerException(this.message);

  String message;
}