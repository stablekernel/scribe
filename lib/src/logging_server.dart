// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.


part of scribe;

class LoggingServer {
  LoggingServer(List<LoggingBackend> backends) {
    _backends = backends;
  }

  List<LoggingBackend> _backends;
  Isolate _loggingIsolate;
  SendPort _destinationPort;

  LoggingTarget getNewTarget() {
    return new LoggingTarget(_destinationPort);
  }

  Future start() async {
    var fromLoggingIsolateReceivePort = new ReceivePort();
    _loggingIsolate = await Isolate.spawn(_logEntryPoint, [fromLoggingIsolateReceivePort.sendPort, _backends]);
    _destinationPort = await fromLoggingIsolateReceivePort.first;
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
  SendPort port = arguments[0];
  List<LoggingBackend> backends = arguments[1];

  await Future.wait(backends.map((b) => b.start()));

  var fromListenerReceivePort = new ReceivePort();
  fromListenerReceivePort.listen((record) {
    backends.forEach((b) => b.log(record));
  });

  port.send(fromListenerReceivePort.sendPort);
  port = null;
}

class LogListenerException implements Exception {
  LogListenerException(this.message);

  String message;
}