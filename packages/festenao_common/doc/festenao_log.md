**Location:** Part of `festenao_common` (`lib/log/`, implementation in `lib/src/log/`)

**Goal**  
Provide a multi-platform (Web / Linux / Windows / Flutter) logging system within `festenao_common` that:

- Always buffers logs locally (even when the remote/local API is unreachable).
- Pushes buffered logs to a configurable remote endpoint as soon as it becomes available.
- Can act both as a **client** (on the kiosk / terminal) and as a **server** (or lightweight receiver).
- Stays fully compatible with the tekartik / tekaly / alextekartik ecosystem.
- Does **not** depend on the official `logging` or `logger` packages (helpers for them may live in separate optional helpers or examples).

---

### 1. Design principles (aligned with tekartik / festenao)

- Pure Dart + Flutter, multi-platform from day one.
- Prefer existing tekartik abstractions:
    - **Storage**: `idb_shim` + **SDB** (preferred for structured logs) and/or `fs_shim` (for simple append-only files / hybrid).
    - Platform detection, HTTP, process helpers, etc. only from tekartik / tekaly packages (git dependencies allowed).
- Zero external logging framework dependency in the core package.
- Explicit, simple, testable APIs.
- Offline-first: local persistence is the source of truth until successfully acknowledged by the remote side.
- Small surface area, clear separation of concerns (client / storage / transport / server).

---

### 2. Core concepts

#### 2.1 Log record

A single log entry contains at least:

| Field            | Type                  | Description |
|------------------|-----------------------|-------------|
| `id`             | `String` (UUID or sequential) | Unique local identifier |
| `timestamp`      | `DateTime` (UTC)      | When the log was created |
| `level`          | `int` or enum         | Severity (debug, info, warning, error, fatal…) |
| `loggerName`     | `String?`             | Optional hierarchical name |
| `message`        | `String`              | Main message |
| `error`          | `String?` / `Object?` | Optional error / exception |
| `stackTrace`     | `String?`             | Optional stack trace |
| `tags` / `extra` | `Map<String, Object?>`| Arbitrary structured data (deviceId, sessionId, location, etc.) |
| `deviceId`       | `String?`             | Identifier of the kiosk / terminal |
| `sessionId`      | `String?`             | Optional session |
| `sent`           | `bool`                | Whether it has been successfully pushed |
| `sentAt`         | `DateTime?`           | When it was acknowledged by the remote |

**Record Limits:**
- **Maximum record size:** **256 KB** per log entry. If a log message, stack trace, or extra payload exceeds 256 KB, it must be truncated prior to storage to guarantee predictable memory & persistence overhead.

Records must be serializable to JSON (and preferably to a compact binary form later if needed).

#### 2.2 Storage backends & Multi-segment Architecture

Three (or hybrid) strategies, selectable at construction time:

1. **SDB / idb_shim** (recommended default)
    - Structured, queryable, works on Web (IndexedDB), IO, and memory.
    - Ideal for filtering, pagination, retention policies, and server-side queries.

2. **fs_shim** (simple file / append-only)
    - One or several log files (rotated by size or date).
    - Lighter for pure sequential write workloads.
    - Still works on Web thanks to fs_shim.

3. **Hybrid**
    - Recent / unsent logs in SDB (fast query + status).
    - Archived / already-sent logs optionally moved to fs_shim files (or vice-versa).
    - Configurable retention and compaction.

#### 2.2.1 Storage Limitations & Master Database Management

To prevent unbounded storage usage on embedded devices, Web (IndexedDB), and desktop nodes, storage is enforced with explicit limits and managed via a **Master Database**:

- **Per-record limit:** **256 KB** max per record.
- **Per-database / file limit:** **10 MB** max per database or log file segment.
- **Duration limit:** Configurable max log age (default: **2 weeks / 14 days**).
- **Total storage size limit:** Configurable total size limit across all segments (e.g. default **100 MB**).

##### Master Database & Rotation Mechanism
- **Master Database (Index):** A lightweight master database maintains an inventory of all active and historical log segment files/databases. It stores metadata for each segment:
  - `segmentId` (e.g. `log_segment_20260731_001`)
  - `path / dbName`
  - `createdAt` & `sealedAt`
  - `oldestTimestamp` & `newestTimestamp`
  - `sizeBytes` & `recordCount`
  - `status` (`active`, `sealed`, `fullySent`, `archived`)
- **Segmentation & Rotation:**
  - Writes only go to the current **active** segment.
  - When the active database or file reaches **10 MB**, it is marked as `sealed` in the master database.
  - A new active database or file segment is created and registered in the master database.
- **Purging & Eviction:**
  - **Age eviction:** Any database/file segment whose logs exceed the duration limit (e.g., older than 2 weeks) is deleted from storage and unregistered from the master database.
  - **Total size eviction:** When total storage across all segments exceeds the total size limit (e.g. 100 MB), the oldest sealed segments are deleted (FIFO) until storage is within limit, even if not yet 2 weeks old.
  - **Fully sent priority:** Sealed segments whose logs are all marked as `sent` are prioritized for deletion during total size eviction.

All backends must support:

- Append
- Mark as sent / delete after successful push
- Query by time range, level, deviceId, sent status
- Basic retention (max count, max age, max size)

#### 2.3 Transport (push)

- Configurable HTTP(S) endpoint (the “local API” or any remote collector).
- Batch upload (configurable max batch size / max age of batch).
- Retry with exponential backoff + jitter.
- Idempotency key (the local `id`) so the server can ignore duplicates.
- Optional compression (gzip) and authentication headers.
- Connectivity / reachability detection (simple ping or first successful request).
- Background / periodic flush + flush-on-demand + flush-on-app-lifecycle events.

#### 2.4 Client API (main usage on the kiosk)

```dart
import 'package:festenao_common/log/log.dart';

final logger = FestenaoLogger(
  storage: SdbLogStorage(...),          // or FsLogStorage / Hybrid
  transport: HttpLogTransport(baseUrl: '...'),
  deviceId: 'borne-42',
  // optional: minLevel, maxBufferSize, flushInterval, etc.
);

logger.log(level: LogLevel.info, message: 'Boot complete', extra: {...});
logger.info('...');
logger.warning('...');
logger.error('...', error: e, stackTrace: st);

// manual control
await logger.flush();
await logger.close();
```

- Fire-and-forget by default (never blocks the UI longer than a few ms).
- Automatic background flusher.
- Optional synchronous mode for critical logs.

#### 2.5 Server / receiver side

The same logging module inside `festenao_common` (exposed via `package:festenao_common/log/log_server.dart` or `package:festenao_common/log/log.dart`) should be able to:

- Expose a simple HTTP endpoint that accepts batches of log records.
- Persist them (again with SDB or fs_shim, or forward to another system).
- Provide basic query / listing helpers (for a future admin UI or Grafana-like exporter).
- Support multi-device aggregation (filter by `deviceId`).

This allows a “local API” running on the same machine, on a LAN server, or in the cloud.

#### 2.6 Log Reader & Exporter Utilities (UI & Diagnostic Tools)

To allow local Flutter apps, admin UI screens, and diagnostic tools to navigate, inspect, search, export, and send logs, `festenao_common` provides dedicated reader and exporter abstractions:

##### 2.6.1 Log Reader API (`FestenaoLogReader`)
A unified reader interface that queries across active and historical segment databases/files (indexed by the Master Database):

- **Querying & Filtering (`LogQueryFilter`):**
  - Time range (`fromDateTime`, `toDateTime`)
  - Log levels (`minLevel`, specific `levels` set)
  - Scope (`deviceId`, `sessionId`, `loggerName`)
  - Delivery status (`sentOnly`, `unsentOnly`, `all`)
  - Text search / keyword (`searchQuery` matching message, loggerName, error, extra)
- **Pagination & Navigation for UI:**
  - `Future<List<LogRecord>> queryLogs(LogQueryFilter filter, {int limit, int offset, bool descending})`
  - `Stream<LogRecord> streamLogs(LogQueryFilter filter)` for real-time log list updates in Flutter widgets.
  - `Future<List<LogSegmentSummary>> getSegmentSummaries()` to list all segments managed by the master DB (creation dates, size, record counts, sent status).

##### 2.6.2 Log Exporter API (`FestenaoLogExporter`)
Utilities to package, download, and transmit log records to external web services:

- **Supported Export Formats:**
  - `Json` (Structured JSON array)
  - `JsonL` (Line-delimited JSON for log ingestion tools)
  - `Csv` (Tabular format for spreadsheet review)
- **Export & Send Operations:**
  - `Future<ExportResult> exportLogsToFile(LogQueryFilter filter, String targetPath, ExportFormat format)`
  - `Future<String> exportLogsToString(LogQueryFilter filter, ExportFormat format)`
  - `Future<SendLogsResult> sendLogsToEndpoint(LogQueryFilter filter, Uri destinationUrl, {Map<String, String>? headers, ExportFormat format})`
    - Queries records matching the filter, serializes them in the requested format, and POSTs them to any custom or third-party web service endpoint.
    - Ideal for an "Export & Send Diagnostics" action triggered from a local Flutter UI.

##### 2.6.3 Usage Example (Flutter UI / Local App Integration)

```dart
import 'package:festenao_common/log/log.dart';

// Create reader linked to storage & master DB
final reader = FestenaoLogReader(storage: logger.storage);

// Query recent warnings and errors for display in a Flutter ListView
final records = await reader.queryLogs(
  LogQueryFilter(
    minLevel: LogLevel.warning,
    fromDateTime: DateTime.now().subtract(const Duration(days: 1)),
    searchQuery: 'network',
  ),
  limit: 50,
  offset: 0,
);

// On-demand export & send triggered by user from a diagnostic UI button
final exporter = FestenaoLogExporter(reader: reader);
final sendResult = await exporter.sendLogsToEndpoint(
  LogQueryFilter(fromDateTime: DateTime.now().subtract(const Duration(hours: 12))),
  Uri.parse('https://diagnostics.example.com/api/v1/logs'),
  headers: {'Authorization': 'Bearer <token>', 'X-Device-Id': 'borne-42'},
  format: ExportFormat.jsonl,
);
```

---

### 3. Module & file structure inside `festenao_common`

```
festenao_common/
├── lib/
│   ├── log/
│   │   ├── log.dart                  # main export (package:festenao_common/log/log.dart)
│   │   ├── log_reader.dart           # log reader & query export
│   │   ├── log_exporter.dart         # export & send utilities export
│   │   ├── log_server.dart           # optional server export
│   │   └── festenao_log.dart         # shortcut / alias export if needed
│   └── src/
│       └── log/
│           ├── log_record.dart
│           ├── log_level.dart
│           ├── logger.dart           # FestenaoLogger
│           ├── reader/
│           │   ├── log_reader.dart   # FestenaoLogReader implementation
│           │   └── log_query_filter.dart
│           ├── exporter/
│           │   ├── log_exporter.dart # FestenaoLogExporter (JSON, JsonL, CSV, sendToEndpoint)
│           │   └── export_format.dart
│           ├── storage/
│           │   ├── log_storage.dart  # abstract
│           │   ├── master_log_db.dart# Master DB index for segment tracking & cleanup
│           │   ├── sdb_log_storage.dart
│           │   ├── fs_log_storage.dart
│           │   └── hybrid_log_storage.dart
│           ├── transport/
│           │   ├── log_transport.dart # abstract
│           │   └── http_log_transport.dart
│           ├── server/               # optional server receiver implementation
│           └── utils/
├── test/
│   └── log/                          # log unit & integration tests
```

Dependencies (strict):

- Integrated into `festenao_common`'s dependencies (tekartik / tekaly / alextekartik packages: idb_shim, sdb, fs_shim, http helpers, platform, etc.).
- No added external dependencies on `logging`, `logger`, `stack_trace` (except if already pulled transitively by a tekartik package), etc.

---

### 4. Compatibility helpers (optional / separate)

A small companion (or example) can provide:

```dart
// Compatible with package:logging
void bindLoggingPackage(FestenaoLogger festenaoLogger) { ... }

// Or a simple Logger-like facade that does not pull the real package
```

These helpers must **not** be part of the core dependency graph of `festenao_common`.

---

### 5. Non-functional requirements

- **Performance**: append must be fast; background flush must not impact UI.
- **Reliability**: never lose a log that was accepted by the client API (until successfully acknowledged or explicitly discarded by retention policy).
- **Web support**: full offline buffering via IndexedDB (idb_shim / SDB) or fs_shim.
- **Testability**: in-memory storage + mock transport for unit tests.
- **Configurability**: levels, batch size, retention, endpoints, headers, device identity… all injectable.
- **Observability**: the logger itself can emit a few internal events (flush success/failure, storage full, etc.) without creating infinite recursion.
- **Versioning & migration**: storage schema versioned (especially for SDB).

---

### 6. Future / optional extensions (out of scope for v1 but keep in mind)

- Log rotation & compression of archived files.
- Encryption at rest.
- WebSocket / SSE push as alternative transport.
- Built-in simple web UI or export to Loki / Grafana / Elasticsearch format.
- Multi-tenant / multi-project support on the server side.
- Metrics (number of pending logs, last successful flush, etc.).

---

### 7. Module structure & ecosystem fit

- **Location**: Exposed inside `festenao_common/lib/log/` (`package:festenao_common/log/log.dart`) with internal implementation in `festenao_common/lib/src/log/`.
- **Not a standalone package**: Designed directly as part of `festenao_common`.
- Follow tekartik naming, documentation style, and testing conventions.

---

This specification gives a clear, implementable foundation that stays offline-first, multi-platform, dependency-light, and consistent with the tekartik/festenao philosophy, while solving exactly the “cache locally → push when the local API is available” requirement (including on Web).