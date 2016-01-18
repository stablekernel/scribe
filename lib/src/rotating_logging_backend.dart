part of scribe;

class RotatingLoggingBackend implements LoggingBackend {
  String _baseFileName;
  int _logIndex = 0;
  int _byteCounter = 0;
  int _logFileCount;
  int _maxSizeInBytes;
  IOSink _fileSink;
  bool _isCycling = false;

  RotatingLoggingBackend(String baseFileName, {int maxSizeInMegabytes: 100, int logFileCount: 3}) {
    _logFileCount = logFileCount;
    _maxSizeInBytes = maxSizeInMegabytes * 1024 * 1024;
    _baseFileName = baseFileName;
  }

  Future start() async {
    var file = new File(_baseFileName);
    _fileSink = await file.openWrite(mode: FileMode.WRITE_ONLY);
  }

  void _logRecord(LogRecord rec) {
    _fileSink.writeln("$rec");
  }

  void log(LogRecord record) {
    try {
      var string = record.toString();
      int byteLength = string.length;

      _byteCounter += byteLength;

      if (_byteCounter / _maxSizeInBytes > 0.99) {
        cycle();
      }

      _logRecord(record);
    } catch (e, stack) {
      var currentDir = Directory.current.path;
      var crashFilePath = [currentDir, "crash.log"].join("/");
      var crashFile = new File(crashFilePath);
      var crashSync = crashFile.openSync(mode: FileMode.WRITE_ONLY);
      crashSync.writeStringSync("Error: $e\nStack Trace:\n$stack");
      crashSync.closeSync();
    }
  }

  Future cycle() async {
    if (_isCycling) {
      return;
    }

    _isCycling = true;

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
  }
}
