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
  List<File>? _logs;
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    LogService.listLogs().then((files) {
      if (mounted) setState(() => _logs = files);
    });
  }

  String _nameFromPath(String path) {
    final name = path.split('/').last.replaceAll('.txt', '');
    if (name.length == 15) {
      return '${name.substring(0, 4)}-${name.substring(4, 6)}-${name.substring(6, 8)} '
          '${name.substring(9, 11)}:${name.substring(11, 13)}:${name.substring(13, 15)}';
    }
    return name;
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
      _selected.addAll(_logs!.map((f) => f.path));
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

    final remaining = await LogService.listLogs();
    if (!mounted) return;
    setState(() {
      _logs = remaining;
      _selected.clear();
    });
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
                      final file = _logs![i];
                      final isSelected = _selected.contains(file.path);
                      return ListTile(
                        leading: _selecting
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelect(file.path),
                              )
                            : const Icon(Icons.fitness_center),
                        title: Text(_nameFromPath(file.path)),
                        selected: isSelected,
                        onTap: _selecting
                            ? () => _toggleSelect(file.path)
                            : () => _showLog(context, file, i),
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

  void _showLog(BuildContext context, File file, int index) async {
    final content = await file.readAsString();
    final log = SessionLog.fromText(content);
    if (!context.mounted) return;

    if (log == null) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_nameFromPath(file.path)),
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
          allLogs: List<File>.from(_logs!),
          initialIndex: index,
        ),
      ),
    );
  }
}
