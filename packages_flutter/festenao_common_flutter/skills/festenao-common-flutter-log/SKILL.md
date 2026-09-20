---
name: festenao-common-flutter-log
description: >-
  Use when adding the festenao log viewer or log playground screens to a
  Flutter app with festenao_common_flutter (lib/log/log.dart):
  FestenaoLogScreen (explorer and playground tabs), FestenaoLogViewerScreen /
  FestenaoLogViewer (filter by level, text and sent state, segment
  management, export to clipboard or send to an endpoint),
  FestenaoLogPlaygroundScreen / FestenaoLogPlayground (emit test records,
  stress tests, flush, rotate, purge), globalFestenaoLogger, and the
  re-exported festenao_common logging api: FestenaoLogger, LogLevel,
  LogRecord, LogStorage (MemoryLogStorage, SdbLogStorage, FsLogStorage,
  HybridLogStorage), LogQueryFilter, FestenaoLogReader, FestenaoLogExporter,
  HttpLogTransport.
---

# Festenao log screens (festenao_common_flutter)

`festenao_common` has a structured logger (`FestenaoLogger`) writing
`LogRecord`s to a rotating segment `LogStorage`, with an optional transport
shipping unsent records to a server. `festenao_common_flutter/log/log.dart`
re-exports it and adds the screens to look at those records in the app: an
explorer and a playground to generate traffic.

## Guidelines

* Import `package:festenao_common_flutter/log/log.dart`: it re-exports
  `package:festenao_common/log/log.dart` (`FestenaoLogger`, `LogLevel`,
  `LogRecord`, `LogStorage` and its implementations, `LogQueryFilter`,
  `LogSegmentSummary`, `FestenaoLogReader`, `FestenaoLogExporter`,
  `ExportFormat`, `LogTransport`, `HttpLogTransport`, `MockLogTransport`)
  plus `FestenaoLogScreen`, `FestenaoLogViewerScreen`, `FestenaoLogViewer`,
  `FestenaoLogPlaygroundScreen`, `FestenaoLogPlayground` and
  `globalFestenaoLogger`. Same git dependency as
  `festenao-common-flutter-setup`.
* Build one `FestenaoLogger(storage:, transport:, loggerName:, deviceId:,
  sessionId:, minLevel:, batchSize:, flushInterval:)` per app and keep it
  alive; log with `log(level:, message:, loggerName:, error:, stackTrace:,
  extra:)` or the shortcuts `debug`/`info`/`warning`/`error`/`fatal`
  (`message, {error, stackTrace, ...}`); `flush()` pushes the pending batch
  to the transport, `close()` at exit. Levels: `LogLevel.debug`, `info`,
  `warning`, `error`, `fatal` (plus `all`/`off`), comparable with `>=`.
* Storages: `MemoryLogStorage()` (dev and tests), `SdbLogStorage(sdbFactory:,
  dbPathPrefix:)` (idb_shim/sqflite database, mobile and web),
  `FsLogStorage(fileSystem:, directoryPath:)` (files, desktop),
  `HybridLogStorage(sdbStorage:, fsStorage:)`; each takes
  `maxSegmentSizeBytes` (10 MB), `maxAge` (14 days) and `maxTotalSizeBytes`
  (100 MB) and rotates/purges accordingly (`rotateSegment()`,
  `purgeOldLogs()`). A storage must be `init()`ed before records are read;
  the logger does it.
* `FestenaoLogScreen(logger:, title:)`: a `DefaultTabController` with the
  explorer (`FestenaoLogViewer(storage: logger.storage)`) and the
  playground (`FestenaoLogPlayground(logger:)`); with `logger` null it uses
  `globalFestenaoLogger`, a lazily created memory logger named
  `festenao.app` (fine for a demo, give your own logger in a real app so
  the screen shows the app's records).
* `FestenaoLogViewer(storage:)` (or its `FestenaoLogViewerScreen(storage:,
  title:)` scaffold): search text, level chips, sent/unsent chips, compact or
  expanded rows, a detail dialog with copy, a segment sheet (rotate, purge,
  the `LogSegmentSummary` list) and an export dialog (`FestenaoLogExporter`:
  json, jsonl or csv to the clipboard, or `sendLogsToEndpoint` to a url).
  It reads with `FestenaoLogReader(storage:).queryLogs(LogQueryFilter(...),
  descending: true)`.
* `FestenaoLogPlayground(logger:)` (or `FestenaoLogPlaygroundScreen(logger:,
  title:)`): emit one record with a chosen level, logger name, message and
  optional json extra; stress tests of 50 to 1000 records (to exercise
  rotation and reader speed); flush, rotate, purge, open the viewer.
* Put the screens behind the dev menu or an admin setting, not in the user
  facing navigation; the playground writes into the real storage.
* Reading records in code: `FestenaoLogReader(storage:)` with
  `queryLogs(filter, limit:, offset:, descending:)`, `streamLogs(filter)`
  and `getSegmentSummaries()`; `LogQueryFilter(fromDateTime:, toDateTime:,
  minLevel:, levels:, deviceId:, sessionId:, loggerName:, sentOnly:,
  searchQuery:)`.

## Examples

### An app logger and a menu entry opening the screen

```dart
import 'package:festenao_common_flutter/log/log.dart';
import 'package:flutter/material.dart';

/// One logger for the app (swap the storage for SdbLogStorage/FsLogStorage
/// in production).
final appLogger = FestenaoLogger(
  storage: MemoryLogStorage(),
  loggerName: 'myapp',
  minLevel: LogLevel.debug,
);

class LogsMenuTile extends StatelessWidget {
  const LogsMenuTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Logs'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FestenaoLogScreen(logger: appLogger, title: 'Logs'),
        ),
      ),
    );
  }
}
```

### Logging from the app

```dart
import 'package:festenao_common_flutter/log/log.dart';

void onCheckout(FestenaoLogger logger, int itemCount) {
  logger.info('checkout done');
  logger.log(
    level: LogLevel.info,
    loggerName: 'shop.checkout',
    message: 'order placed',
    extra: {'items': itemCount},
  );
}

Future<void> onFailure(FestenaoLogger logger, Object e, StackTrace st) async {
  logger.error('sync failed', error: e, stackTrace: st);
  await logger.flush(); // push to the transport now
}

/// Quick and dirty, memory only: the global logger.
void quickTrace(String message) => globalFestenaoLogger.debug(message);
```

### Viewer only, and the same query in code

```dart
import 'package:festenao_common_flutter/log/log.dart';
import 'package:flutter/material.dart';

Widget errorsScreen(LogStorage storage) =>
    FestenaoLogViewerScreen(storage: storage, title: 'Errors');

Future<List<LogRecord>> recentErrors(LogStorage storage) async {
  var reader = FestenaoLogReader(storage: storage);
  return reader.queryLogs(
    const LogQueryFilter(minLevel: LogLevel.error),
    limit: 50,
    descending: true,
  );
}
```

## Common mistakes

* Showing `FestenaoLogScreen()` without a logger in a real app: it shows
  the empty global memory logger, not the app records.
* Creating a second `FestenaoLogger` on the same storage for the screen;
  reuse the app one.
* Leaving the playground reachable by end users (it fills the storage).
