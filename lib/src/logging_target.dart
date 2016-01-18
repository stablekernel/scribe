part of scribe;

class LoggingTarget {
  LoggingTarget(this._toLoggerIsolatePort);

  SendPort _toLoggerIsolatePort;

  Future bind(Logger logger) async {
    logger.onRecord.listen(_listener);
  }

  void _listener(LogRecord record) {
    _toLoggerIsolatePort
        .send(new _SafeLogRecord(record.level, record.message, record.loggerName, record.time, record.stackTrace));
  }
}
