import 'package:scribe/scribe.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'dart:async';

void main() {
  test("Backend that fails during start throws appropriate exception", () async {
    var s = new LoggingServer([new BadStartupBackend()]);
    try {
      await s.start();
      expect(true, false);
    } on String catch (str) {
      expect(str, "Startup failed");
    }
  });

  test("Backend that fails during message propogates that message back to error stream", () async {
    var s = new LoggingServer([new BadMessageBackend()]);
    var completers = <Completer>[new Completer(), new Completer()];
    s.errorStream.listen((r) {}, onError: (e, st) {
      completers.first.complete();
      completers.removeAt(0);

    });
    await s.start();

    var logger = new Logger("aq");
    s.getNewTarget().bind(logger);

    logger.info("1");
    logger.info("2");

    await Future.wait(completers.map((c) => c.future));
    await s.stop();
  });
}

class BadStartupBackend implements LoggingBackend {
  Future start() async {
    throw "Startup failed";
  }

  Future stop() async {
  }

  void log(SafeLogRecord record) {
  }
}

class BadMessageBackend implements LoggingBackend {
  Future start() async {
  }

  Future stop() async {
  }

  void log(SafeLogRecord record) {
    throw "Log failed";
  }
}