part of scribe;

abstract class LoggingBackend {
  Future start();
  void log(LogRecord record);
}
