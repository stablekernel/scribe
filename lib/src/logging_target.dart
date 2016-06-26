part of scribe;

/// Used to bind a [Logger] to a [LoggingServer].
///
/// A [LoggingServer] receives log messages through its [LoggingTarget]s. These target may be passed across [Isolate]s.
/// Use [LoggingServer.getNewTarget] to get a new instance of [LoggingTarget].
/// Pass a [Logger] to the [bind] method to send its messages to the owning [LoggingServer].
class LoggingTarget {
  /// Constructor for [LoggingTarget].
  ///
  /// Do not invoke this yourself.
  LoggingTarget(this._toLoggerIsolatePort);

  SendPort _toLoggerIsolatePort;

  /// Binds a [Logger] to this target.
  ///
  /// To start sending [logger] messages to the owner of this target, you must invoke this method.
  Future bind(Logger logger) async {
    logger.onRecord.listen(_listener);
  }

  void _listener(LogRecord record) {
    _toLoggerIsolatePort?.send(new _SafeLogRecord(record.level, record.message, record.loggerName, record.time, record.stackTrace));
  }
}
