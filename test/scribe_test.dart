// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:scribe/scribe.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'dart:async';

void main() {
  group('Default Console Logger', () {
    var logger = new Logger("defaultConsoleLogger");
    var listener = new LoggingServer([new ConsoleBackend()]);

    setUp(() async {
      await listener.start();
      await listener.getNewTarget().bind(logger);
    });

    tearDown(() async {
      await listener.stop();
    });

    test("Receives output", () async {
      // I have no idea how to test this other than looking at the console?
      // maybe running it as a separate app and grabbing the Process.stdout?
      logger.info("Async Console");
    });
  });

  group('Sync Console Logger', () {
    var logger = new Logger("syncConsoleLogger");
    var listener = new LoggingServer([new ConsoleBackend(nonBlocking: false)]);

    setUp(() async {
      await listener.start();
      await listener.getNewTarget().bind(logger);
    });
    tearDown(() async {
      await listener.stop();
    });

    test("Receives output", () async {
      // I have no idea how to test this other than looking at the console?
      logger.info("Sync Console");
    });
  });


  group('Rotating Logger', () {
    Logger logger = null;
    LoggingServer listener = null;
    Directory testDirectory = new Directory("${Directory.current.path}/tmptest");

    setUp(() async {
      testDirectory.createSync();
    });

    tearDown(() async {
      await listener.stop();
      testDirectory.deleteSync(recursive: true);
    });

    test("Receives output", () async {
      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      logger.info("Hello");

      await new Future.delayed(new Duration(milliseconds: 100));

      var contents = new File("${Directory.current.path}/test.log").readAsStringSync();
      expect(contents, startsWith("[INFO]"));
      expect(contents, endsWith("Hello\n"));
    });

    test("Log rotates on byte count", () async {
      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      String bytes = new List.generate(1024, (idx) => 'a').join("");
      var comp = new Completer();
      int counter = 0;
      new Timer.periodic(new Duration(milliseconds: 1), (Timer t) {
        logger.info(bytes);
        counter ++;
        if (counter > 1500) {
          t.cancel();
          comp.complete();
        }
      });

      await comp.future;

      var f1 = new File("${testDirectory.path}/test.log");
      var f2 = new File("${testDirectory.path}/test.log.0");
      expect(f1.existsSync(), true);
      expect(f2.existsSync(), true);

      expect(f1.readAsStringSync(), contains("rotatingLogger: aa"));
      expect(f2.readAsStringSync(), contains("rotatingLogger: aa"));
    });

    test("Log rotates on duration", () async {
      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", duration: new Duration(seconds: 1))]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      var comp = new Completer();
      int counter = 0;
      new Timer.periodic(new Duration(milliseconds: 501), (Timer t) {
        logger.info("Hello");
        counter ++;
        if (counter == 5) {
          t.cancel();
          comp.complete();
        }
      });

      await comp.future;

      var f1 = new File("${testDirectory.path}/test.log");
      var f2 = new File("${testDirectory.path}/test.log.0");
      var f3 = new File("${testDirectory.path}/test.log.1");
      expect(f1.existsSync(), true);
      expect(f2.existsSync(), true);
      expect(f3.existsSync(), true);

      expect(f1.readAsStringSync(), contains("rotatingLogger: Hello"));
      expect(f2.readAsStringSync(), contains("rotatingLogger: Hello"));
      expect(f3.readAsStringSync(), contains("rotatingLogger: Hello"));

      expect(testDirectory.listSync()
          .where((fs) => fs is File)
          .where((File fs) => fs.uri.path.contains("test.log")).length, 3);
    });
  });

  group('Rotating Logger, file moving', () {
    Directory testDirectory = new Directory("${Directory.current.path}/tmptest");

    setUp(() async {
      testDirectory.createSync();
    });

    tearDown(() async {
      testDirectory.deleteSync(recursive: true);
    });

    test("Restart moves previous log", () async {
      Logger logger = null;
      LoggingServer listener = null;

      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      logger.info("Log 1");
      await new Future.delayed(new Duration(milliseconds: 100));
      await listener.stop();

      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      logger.info("Log 2");
      await new Future.delayed(new Duration(milliseconds: 100));
      await listener.stop();

      var f1 = new File("${testDirectory.path}/test.log");
      var f2 = new File("${testDirectory.path}/test.log.0");
      expect(f1.existsSync(), true);
      expect(f2.existsSync(), true);

      expect(f1.readAsStringSync(), contains("rotatingLogger: Log 2"));
      expect(f2.readAsStringSync(), contains("rotatingLogger: Log 1"));
    });

    test("Restart moves previous log, even if log.0 is there", () async {
      var f0 = new File("${testDirectory.path}/test.log.0");
      f0.writeAsStringSync("doesn't matter");

      Logger logger = null;
      LoggingServer listener = null;

      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      logger.info("Log 1");
      await new Future.delayed(new Duration(milliseconds: 100));
      await listener.stop();

      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${testDirectory.path}/test.log", maxSizeInMegabytes: 1)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);

      logger.info("Log 2");
      await new Future.delayed(new Duration(milliseconds: 100));
      await listener.stop();

      var f1 = new File("${testDirectory.path}/test.log");
      var f2 = new File("${testDirectory.path}/test.log.0");
      expect(f1.existsSync(), true);
      expect(f2.existsSync(), true);

      expect(f1.readAsStringSync(), contains("rotatingLogger: Log 2"));
      expect(f2.readAsStringSync(), contains("rotatingLogger: Log 1"));
    });
  });

}
