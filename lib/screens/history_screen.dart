import 'dart:io';
import 'package:flutter/material.dart';
import '../models/session_log.dart';
import '../services/config_service.dart';
import '../services/log_service.dart';
import 'summary_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<(File, SessionLog?)>? _logs;
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final files = await LogService.listLogs();
    final entries = <(File, SessionLog?)>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        entries.add((file, SessionLog.fromText(content)));
      } catch (_) {
        entries.add((file, null));
      }
    }
    if (mounted) setState(() => _logs = entries);
  }

  String _titleFor(File file, SessionLog? log) {
    if (log != null && log.planName.isNotEmpty) return log.planName;
    return 'Training Session';
  }

  String _subtitleFor(SessionLog log) {
    final dt = log.startTime;
    final date =
        '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    final minutes = (log.duration.inSeconds / 60).round();
    final status = log.completed ? 'Completed' : 'Interrupted';
    return '$date · $minutes min · $status';
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_logs!.map((e) => e.$1.path));
    });
  }

  void _cancelSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sessions'),
        content: Text('Delete $count session${count == 1 ? '' : 's'}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    for (final path in _selected) {
      await File(path).delete();
    }

    await _loadLogs();
    if (mounted) setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelSelection();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionAppBar() : AppBar(title: const Text('Session History')),
        body: SafeArea(
          top: false,
          child: _logs == null
            ? const Center(child: CircularProgressIndicator())
            : _logs!.isEmpty
                ? const Center(child: Text('No sessions recorded yet'))
                : ListView.builder(
                    itemCount: _logs!.length,
                    itemBuilder: (_, i) {
                      final (file, log) = _logs![i];
                      final isSelected = _selected.contains(file.path);
                      return ListTile(
                        leading: _selecting
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelect(file.path),
                              )
                            : const Icon(Icons.fitness_center),
                        title: Text(_titleFor(file, log)),
                        subtitle: log != null ? Text(_subtitleFor(log)) : null,
                        selected: isSelected,
                        onTap: _selecting
                            ? () => _toggleSelect(file.path)
                            : () => _showLog(context, file, log, i),
                        onLongPress: _selecting ? null : () => _toggleSelect(file.path),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  AppBar _selectionAppBar() {
    final allSelected = _logs != null && _selected.length == _logs!.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: allSelected ? _cancelSelection : _selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete selected',
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  void _showLog(BuildContext context, File file, SessionLog? log, int index) async {
    if (log == null) {
      final content = await file.readAsString();
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Training Session'),
          content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontFamily: 'monospace'))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
      return;
    }

    final config = await ConfigService.create();
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          log: log,
          profile: config.userProfile,
          allLogs: _logs!.map((e) => e.$1).toList(),
          initialIndex: index,
        ),
      ),
    );
  }
}
