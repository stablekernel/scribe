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

    setUp(() async {
      logger = new Logger("rotatingLogger");
      listener = new LoggingServer([new RotatingLoggingBackend("${Directory.current.path}/test.log", maxSizeInMegabytes: 2)]);
      await listener.start();
      await listener.getNewTarget().bind(logger);
    });
    tearDown(() async {
      await listener.stop();
    });

    test("Receives output", () async {
      String bytes = new List.generate(1024, (idx) => 'a').join("");
      var comp = new Completer();
      int counter = 0;
      new Timer.periodic(new Duration(milliseconds: 1), (Timer t) {
        logger.info(bytes);
        counter ++;
        if (counter > 4000) {
          t.cancel();
          comp.complete();
        }
      });

      await comp.future;
    });
  });

}
