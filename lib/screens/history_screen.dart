import 'dart:io';
import 'package:flutter/material.dart';
import '../services/log_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<File>? _logs;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
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
                    return ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text(_nameFromPath(file.path)),
                      onTap: () => _showLog(context, file),
                    );
                  },
                ),
      ),
    );
  }

  void _showLog(BuildContext context, File file) async {
    final content = await file.readAsString();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_nameFromPath(file.path)),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontFamily: 'monospace'))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
