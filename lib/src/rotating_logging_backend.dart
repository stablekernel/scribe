part of scribe;

/// Logging backend for [LoggingServer] that logs messages to rotating log files.
class RotatingLoggingBackend implements LoggingBackend {
  /// Creates a new [RotatingLoggingBackend].
  ///
  /// You must specify a base file name, such as 'api.log'. Rotated logs will be suffixed with an index, e.g., 'api.log.0'.
  ///
  /// By default, logs are rotated every 24 hours or when they reach 100MB of data. Three log files are kept in rotation.
  ///
  /// You may change these defaults by passing [duration], [maxSizeInMegabytes] and [logFileCount].
  RotatingLoggingBackend(String baseFileName, {Duration duration: const Duration(days: 1), int maxSizeInMegabytes: 100, int logFileCount: 3}) {
    _logFileCount = logFileCount;
    _maxSizeInBytes = maxSizeInMegabytes * 1024 * 1024;
    _baseFileName = baseFileName;
    _duration = duration;
  }

  String _baseFileName;
  int _logIndex = 0;
  Duration _duration;
  int _byteCounter = 0;
  int _logFileCount;
  int _maxSizeInBytes;
  IOSink _fileSink;
  bool _isCycling = false;
  Timer _timer;

  Future start() async {
    var file = new File(_baseFileName);
    if (file.existsSync()) {
      file.rename("${_baseFileName}.0");
      file = new File(_baseFileName);
    }
    _fileSink = await file.openWrite(mode: FileMode.WRITE_ONLY);
    _timer = new Timer.periodic(_duration, (_) {
      cycle();
    });
  }

  Future stop() async {
    _timer.cancel();
    await _fileSink.close();

    _fileSink = null;
  }

  void _logRecord(LogRecord rec) {
    _fileSink?.writeln("$rec");
  }

  void log(LogRecord record) {
    try {
      var string = record.toString();
      int byteLength = string.length;

      _byteCounter += byteLength;

      if (_byteCounter / _maxSizeInBytes >= 1.0) {
        cycle();
      }

      _logRecord(record);
    } catch (e, stack) {
      _loggerError(e, stack);
    }
  }

  void _loggerError(dynamic e, StackTrace stack) {
    var currentDir = Directory.current.path;
    var crashFilePath = [currentDir, "crash.log"].join("/");
    var crashFile = new File(crashFilePath);
    var crashSync = crashFile.openSync(mode: FileMode.WRITE_ONLY);
    crashSync.writeStringSync("Error: $e\nStack Trace:\n$stack");
    crashSync.closeSync();
  }

  Future cycle() async {
    if (_isCycling) {
      return;
    }

    _isCycling = true;

    try {
      var existingFile = new File(_baseFileName);
      await existingFile.rename("${_baseFileName}.${_logIndex}");

      var file = new File(_baseFileName);
      var newSink = await file.openWrite(mode: FileMode.WRITE_ONLY);
      var oldSink = _fileSink;
      _fileSink = newSink;
      _logIndex = (_logIndex + 1) % _logFileCount;
      _byteCounter = 0;

      oldSink?.close();
      _isCycling = false;
    } catch (e, stack) {
      _loggerError(e, stack);
    }
  }
}
