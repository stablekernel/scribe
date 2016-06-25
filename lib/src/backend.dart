part of scribe;

abstract class LoggingBackend {
  Future start();
  Future stop();

  void log(LogRecord record);
}
