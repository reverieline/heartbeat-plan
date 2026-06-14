import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/training_plan.dart';
import '../services/plan_service.dart';

class PlanEditorScreen extends StatefulWidget {
  final String planName;
  final bool isNew;

  const PlanEditorScreen({super.key, required this.planName, required this.isNew});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final TextEditingController _nameController;
  List<TrainingStage> _stages = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.planName);
    _loadPlan();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    if (widget.isNew) {
      setState(() => _loading = false);
      return;
    }
    try {
      final stages = await PlanService.loadPlan(widget.planName);
      if (mounted) {
        setState(() {
          _stages = List.from(stages);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan name cannot be empty')),
      );
      return;
    }

    final originalName = widget.planName;
    final isRename = !widget.isNew && originalName != newName;

    if (isRename) {
      final exists = await PlanService.planExists(newName);
      if (!mounted) return;
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A plan named "$newName" already exists')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await PlanService.savePlan(newName, _stages);
      if (isRename) await PlanService.deletePlan(originalName);
      if (mounted) Navigator.pop(context, newName);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _addStage() => _editStage(null, null);

  void _editStage(TrainingStage? existing, int? index) {
    showModalBottomSheet<TrainingStage>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StageEditSheet(stage: existing),
    ).then((result) {
      if (result == null) return;
      setState(() {
        if (index == null) {
          _stages.add(result);
        } else {
          _stages[index] = result;
        }
      });
    });
  }

  void _duplicateStage(int index) {
    setState(() => _stages.insert(index + 1, _stages[index]));
  }

  void _deleteStage(int index) {
    setState(() => _stages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New Plan' : 'Edit Plan'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Plan name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _stages.isEmpty
                      ? _EmptyState(onAdd: _addStage)
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _stages.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final stage = _stages.removeAt(oldIndex);
                              _stages.insert(newIndex, stage);
                            });
                          },
                          itemBuilder: (ctx, i) {
                            final stage = _stages[i];
                            return _StageTile(
                              key: ValueKey('$i-${stage.name}'),
                              index: i,
                              stage: stage,
                              onEdit: () => _editStage(stage, i),
                              onDuplicate: () => _duplicateStage(i),
                              onDelete: () => _deleteStage(i),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _stages.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addStage,
              tooltip: 'Add stage',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No stages yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Stage'),
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final int index;
  final TrainingStage stage;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _StageTile({
    super.key,
    required this.index,
    required this.stage,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mins = stage.durationMinutes % 1 == 0
        ? '${stage.durationMinutes.toInt()} min'
        : '${stage.durationMinutes} min';

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(stage.name),
      subtitle: Text('$mins · ${stage.target.label}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit stage',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: 'Duplicate stage',
            onPressed: onDuplicate,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove stage',
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _StageEditSheet extends StatefulWidget {
  final TrainingStage? stage;
  const _StageEditSheet({this.stage});

  @override
  State<_StageEditSheet> createState() => _StageEditSheetState();
}

class _StageEditSheetState extends State<_StageEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _minBpmCtrl;
  late final TextEditingController _maxBpmCtrl;
  late TargetMode _mode;

  @override
  void initState() {
    super.initState();
    final s = widget.stage;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _durationCtrl = TextEditingController(
      text: s == null
          ? ''
          : s.durationMinutes % 1 == 0
              ? s.durationMinutes.toInt().toString()
              : s.durationMinutes.toString(),
    );
    _mode = s?.target.mode ?? TargetMode.none;
    _minBpmCtrl = TextEditingController(text: s?.target.minBpm?.toString() ?? '');
    _maxBpmCtrl = TextEditingController(text: s?.target.maxBpm?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _minBpmCtrl.dispose();
    _maxBpmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final duration = double.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration <= 0) return;

    final needsMin = _mode == TargetMode.min || _mode == TargetMode.range;
    final needsMax = _mode == TargetMode.max || _mode == TargetMode.range;
    final minBpm = needsMin ? int.tryParse(_minBpmCtrl.text.trim()) : null;
    final maxBpm = needsMax ? int.tryParse(_maxBpmCtrl.text.trim()) : null;
    if (needsMin && minBpm == null) return;
    if (needsMax && maxBpm == null) return;

    Navigator.pop(
      context,
      TrainingStage(
        name: name,
        durationMinutes: duration,
        target: StageTarget(mode: _mode, minBpm: minBpm, maxBpm: maxBpm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final showMin = _mode == TargetMode.min || _mode == TargetMode.range;
    final showMax = _mode == TargetMode.max || _mode == TargetMode.range;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.stage == null ? 'Add Stage' : 'Edit Stage',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Stage name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Duration (minutes)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('HR target', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<TargetMode>(
            segments: const [
              ButtonSegment(value: TargetMode.none, label: Text('None')),
              ButtonSegment(value: TargetMode.min, label: Text('Min')),
              ButtonSegment(value: TargetMode.max, label: Text('Max')),
              ButtonSegment(value: TargetMode.range, label: Text('Range')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          if (showMin) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _minBpmCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Min BPM',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (showMax) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _maxBpmCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Max BPM',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
