/// The scribe library.
///
/// Implements logging backends for logging package.
library scribe;

import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:logging/logging.dart';

part 'src/logging_server.dart';
part 'src/backend.dart';
part 'src/rotating_logging_backend.dart';
part 'src/console_logging_backend.dart';
part 'src/logging_target.dart';
