import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxFileBytes = 2 * 1024 * 1024;
  static const int _maxFiles = 5;

  Directory? _logDirectory;
  File? _activeLogFile;
  bool _initialized = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> init() async {
    if (_initialized) return;

    final baseDir = await getApplicationDocumentsDirectory();
    final logDirectory = Directory('${baseDir.path}/logs');
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }

    final activeLogFile = File('${logDirectory.path}/app.log');
    if (!await activeLogFile.exists()) {
      await activeLogFile.create(recursive: true);
    }

    _logDirectory = logDirectory;
    _activeLogFile = activeLogFile;
    _initialized = true;

    await info('AppLogger', 'Initialized at ${logDirectory.path}');
  }

  Future<void> info(String tag, String message) {
    return _log(level: 'INFO', tag: tag, message: message);
  }

  Future<void> warn(String tag, String message) {
    return _log(level: 'WARN', tag: tag, message: message);
  }

  Future<void> error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return _log(
      level: 'ERROR',
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String?> getLogDirectoryPath() async {
    await _ensureReady();
    return _logDirectory?.path;
  }

  Future<List<File>> getLogFiles() async {
    await _ensureReady();
    final logDirectory = _logDirectory;
    if (logDirectory == null || !await logDirectory.exists()) return [];

    final files = <File>[];
    for (final entity in logDirectory.listSync()) {
      if (entity is File && entity.path.endsWith('.log')) {
        files.add(entity);
      }
    }

    files.sort((a, b) {
      final aName = a.uri.pathSegments.isNotEmpty
          ? a.uri.pathSegments.last
          : a.path;
      final bName = b.uri.pathSegments.isNotEmpty
          ? b.uri.pathSegments.last
          : b.path;
      if (aName == 'app.log') return -1;
      if (bName == 'app.log') return 1;
      return aName.compareTo(bName);
    });

    return files;
  }

  Future<void> _log({
    required String level,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await _ensureReady();

    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer('$now [$level][$tag] $message');
    if (error != null) {
      buffer.write(' | error=$error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    final line = '${buffer.toString()}\n';

    debugPrint(buffer.toString());

    _writeQueue = _writeQueue.then((_) async {
      try {
        await _rotateIfNeeded(incomingBytes: line.length);
        await _activeLogFile?.writeAsString(
          line,
          mode: FileMode.append,
          flush: true,
        );
      } catch (e) {
        debugPrint('[AppLogger] Failed to write log: $e');
      }
    });

    await _writeQueue;
  }

  Future<void> _ensureReady() async {
    if (!_initialized) {
      await init();
    }
  }

  Future<void> _rotateIfNeeded({required int incomingBytes}) async {
    final active = _activeLogFile;
    if (active == null) return;

    int currentLength = 0;
    if (await active.exists()) {
      currentLength = await active.length();
    }

    if (currentLength + incomingBytes < _maxFileBytes) {
      return;
    }

    final logDirectory = _logDirectory;
    if (logDirectory == null) return;

    final oldest = File('${logDirectory.path}/app.${_maxFiles - 1}.log');
    if (await oldest.exists()) {
      await oldest.delete();
    }

    for (int i = _maxFiles - 2; i >= 1; i--) {
      final source = File('${logDirectory.path}/app.$i.log');
      if (await source.exists()) {
        await source.rename('${logDirectory.path}/app.${i + 1}.log');
      }
    }

    if (await active.exists()) {
      await active.rename('${logDirectory.path}/app.1.log');
    }

    _activeLogFile = File('${logDirectory.path}/app.log');
    if (!await _activeLogFile!.exists()) {
      await _activeLogFile!.create(recursive: true);
    }
  }
}
