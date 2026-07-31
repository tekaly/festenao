import 'package:festenao_common/log/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen wrapper for [FestenaoLogViewer].
class FestenaoLogViewerScreen extends StatelessWidget {
  /// Storage engine.
  final LogStorage storage;

  /// Custom screen title.
  final String? title;

  /// Creates a new [FestenaoLogViewerScreen].
  const FestenaoLogViewerScreen({
    super.key,
    required this.storage,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Log Explorer'),
      ),
      body: FestenaoLogViewer(storage: storage),
    );
  }
}

/// Full-featured log viewer widget providing segment navigation, filtering,
/// details inspection, segment deletion/purge, and export/send functionality.
class FestenaoLogViewer extends StatefulWidget {
  /// Storage engine to read and manage log segments from.
  final LogStorage storage;

  /// Creates a new [FestenaoLogViewer] widget.
  const FestenaoLogViewer({
    super.key,
    required this.storage,
  });

  @override
  State<FestenaoLogViewer> createState() => _FestenaoLogViewerState();
}

enum _ViewMode { compact, expanded }

class _FestenaoLogViewerState extends State<FestenaoLogViewer> {
  late FestenaoLogReader _reader;
  late FestenaoLogExporter _exporter;

  final TextEditingController _searchController = TextEditingController();
  LogLevel? _selectedLevel;
  bool? _sentOnly; // null = all, false = unsent, true = sent
  _ViewMode _viewMode = _ViewMode.compact;

  List<LogRecord> _records = [];
  List<LogSegmentSummary> _segmentSummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reader = FestenaoLogReader(storage: widget.storage);
    _exporter = FestenaoLogExporter(reader: _reader);
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    try {
      final summaries = await _reader.getSegmentSummaries();
      final filter = LogQueryFilter(
        searchQuery: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        minLevel: _selectedLevel,
        sentOnly: _sentOnly,
      );
      final records = await _reader.queryLogs(filter, descending: true);

      if (mounted) {
        setState(() {
          _segmentSummaries = summaries;
          _records = records;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _levelColor(LogLevel level) {
    if (level >= LogLevel.fatal) return Colors.purple.shade700;
    if (level >= LogLevel.error) return Colors.red.shade700;
    if (level >= LogLevel.warning) return Colors.orange.shade800;
    if (level >= LogLevel.info) return Colors.blue.shade700;
    return Colors.grey.shade700;
  }

  void _showRecordDetails(LogRecord record) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _levelColor(record.level),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.level.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.loggerName ?? 'Log Details',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow('ID', record.id),
                  _detailRow('Timestamp (UTC)', record.timestamp.toIso8601String()),
                  if (record.deviceId != null)
                    _detailRow('Device ID', record.deviceId!),
                  if (record.sessionId != null)
                    _detailRow('Session ID', record.sessionId!),
                  _detailRow(
                      'Sent Status',
                      record.sent
                          ? 'Sent (${record.sentAt?.toIso8601String() ?? "yes"})'
                          : 'Unsent'),
                  const Divider(),
                  const Text('Message:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(record.message),
                  if (record.error != null) ...[
                    const SizedBox(height: 12),
                    const Text('Error:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 4),
                    SelectableText(record.error!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                  if (record.stackTrace != null) ...[
                    const SizedBox(height: 12),
                    const Text('Stack Trace:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            record.stackTrace!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (record.extra != null && record.extra!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Extra Metadata:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(record.extra.toString()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: record.toMap().toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied record to clipboard')),
                );
              },
              child: const Text('Copy Map'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSegmentManagement() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Master DB Segments & Files',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.rotate_right, size: 16),
                        label: const Text('Rotate Segment'),
                        onPressed: () async {
                          await widget.storage.rotateSegment();
                          await _reload();
                          setSheetState(() {});
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cleaning_services, size: 16),
                        label: const Text('Purge Old Logs'),
                        onPressed: () async {
                          await widget.storage.purgeOldLogs();
                          await _reload();
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _segmentSummaries.length,
                      itemBuilder: (context, index) {
                        final seg = _segmentSummaries[index];
                        final sizeMb =
                            (seg.sizeBytes / (1024 * 1024)).toStringAsFixed(2);
                        return ListTile(
                          leading: Icon(
                            seg.status == 'active'
                                ? Icons.create
                                : Icons.lock_outline,
                            color: seg.status == 'active'
                                ? Colors.green
                                : Colors.grey,
                          ),
                          title: Text(
                            '${seg.segmentId} (${seg.status})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Records: ${seg.recordCount} | Size: ${sizeMb}MB\nCreated: ${seg.createdAt.toIso8601String().substring(0, 19)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showExportDialog() {
    var chosenFormat = ExportFormat.json;
    final urlController =
        TextEditingController(text: 'https://diagnostics.example.com/api/v1/logs');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Export & Send Logs'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Export Format:'),
                  DropdownButton<ExportFormat>(
                    value: chosenFormat,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: ExportFormat.json, child: Text('JSON Array')),
                      DropdownMenuItem(
                          value: ExportFormat.jsonl,
                          child: Text('JSONL (Line-delimited)')),
                      DropdownMenuItem(
                          value: ExportFormat.csv, child: Text('CSV Spreadsheet')),
                    ],
                    onChanged: (fmt) {
                      if (fmt != null) {
                        setDialogState(() => chosenFormat = fmt);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Remote Endpoint URL (for Send):'),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://...',
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final str = await _exporter.exportLogsToString(
                      LogQueryFilter(
                        minLevel: _selectedLevel,
                        sentOnly: _sentOnly,
                        searchQuery: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim(),
                      ),
                      format: chosenFormat,
                    );
                    await Clipboard.setData(ClipboardData(text: str));
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Exported ${chosenFormat.name.toUpperCase()} copied to clipboard')),
                      );
                    }
                  },
                  child: const Text('Copy to Clipboard'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final destination = Uri.tryParse(urlController.text.trim());
                    if (destination == null) return;
                    Navigator.of(dialogContext).pop();

                    final result = await _exporter.sendLogsToEndpoint(
                      LogQueryFilter(
                        minLevel: _selectedLevel,
                        sentOnly: _sentOnly,
                        searchQuery: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim(),
                      ),
                      destination,
                      format: chosenFormat,
                    );

                    if (mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(result.success ? 'Success' : 'Failed'),
                          content: Text(
                            'Status Code: ${result.statusCode}\nRecords Sent: ${result.recordCount}\nResponse: ${result.responseBody ?? "(none)"}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Send to Endpoint'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search message, logger, error...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _reload();
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _reload(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_viewMode == _ViewMode.compact
                        ? Icons.view_headline
                        : Icons.view_agenda),
                    tooltip: 'Toggle View Mode',
                    onPressed: () {
                      setState(() {
                        _viewMode = _viewMode == _ViewMode.compact
                            ? _ViewMode.expanded
                            : _ViewMode.compact;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.storage),
                    tooltip: 'Master DB Segments',
                    onPressed: _showSegmentManagement,
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Export & Send',
                    onPressed: _showExportDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('ALL'),
                      selected: _selectedLevel == null,
                      onSelected: (val) {
                        setState(() => _selectedLevel = null);
                        _reload();
                      },
                    ),
                    const SizedBox(width: 4),
                    ...[
                      LogLevel.debug,
                      LogLevel.info,
                      LogLevel.warning,
                      LogLevel.error,
                      LogLevel.fatal,
                    ].map((level) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: FilterChip(
                          label: Text(level.name),
                          selected: _selectedLevel == level,
                          selectedColor: _levelColor(level).withValues(alpha: 0.3),
                          onSelected: (val) {
                            setState(() => _selectedLevel = val ? level : null);
                            _reload();
                          },
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All Delivery'),
                      selected: _sentOnly == null,
                      onSelected: (val) {
                        setState(() => _sentOnly = null);
                        _reload();
                      },
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('Unsent'),
                      selected: _sentOnly == false,
                      onSelected: (val) {
                        setState(() => _sentOnly = val ? false : null);
                        _reload();
                      },
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('Sent'),
                      selected: _sentOnly == true,
                      onSelected: (val) {
                        setState(() => _sentOnly = val ? true : null);
                        _reload();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Record Count Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_records.length} records (${_segmentSummaries.length} segments)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _reload,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Records List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? const Center(
                      child: Text('No log records match current filters'),
                    )
                  : ListView.separated(
                      itemCount: _records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        if (_viewMode == _ViewMode.compact) {
                          return _buildCompactItem(record);
                        } else {
                          return _buildExpandedItem(record);
                        }
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCompactItem(LogRecord record) {
    final tsStr = record.timestamp.toIso8601String().substring(11, 19);
    return ListTile(
      dense: true,
      onTap: () => _showRecordDetails(record),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _levelColor(record.level),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          record.level.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      ),
      title: Text(
        record.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: record.loggerName != null ? Text(record.loggerName!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tsStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(width: 6),
          Icon(
            record.sent ? Icons.check_circle : Icons.schedule,
            size: 14,
            color: record.sent ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedItem(LogRecord record) {
    return InkWell(
      onTap: () => _showRecordDetails(record),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _levelColor(record.level),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.level.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                if (record.loggerName != null) ...[
                  Text(
                    record.loggerName!,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  record.timestamp.toIso8601String().substring(0, 19),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              record.message,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            if (record.error != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${record.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (record.deviceId != null)
                  Text('Device: ${record.deviceId} | ',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                Text(record.sent ? 'Status: Sent' : 'Status: Unsent',
                    style: TextStyle(
                        color: record.sent ? Colors.green : Colors.orange,
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
