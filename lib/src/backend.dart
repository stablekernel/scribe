part of scribe;

/// Interface for specific logging backends used by [LoggingServer].
abstract class LoggingBackend {

  /// Received when [LoggingServer] starts.
  ///
  /// This method should prepare this backend to start receiving [LogRecord]s.
  Future start();

  /// Received when [LoggingServer] stops.
  ///
  /// This method should tear down any resources used by this backend.
  Future stop();

  /// Received when [LoggingServer] sends a log message.
  ///
  /// This method is the core method of this backend. It will interpret and 'log' the [record] as determined by this backend.
  void log(LogRecord record);
}
