import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/plan_service.dart';
import 'plan_editor_screen.dart';

class PlanListScreen extends ConsumerWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(planListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Training Plans')),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No plans found'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final name = list[i];
                  return ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () => _openEditor(context, ref, name),
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_copy),
                          tooltip: 'Duplicate',
                          onPressed: () => _duplicatePlan(context, ref, name),
                        ),
                        if (name != 'default')
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(context, ref, name),
                          ),
                      ],
                    ),
                    onTap: () => _openEditor(context, ref, name),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlan(context, ref),
        tooltip: 'New plan',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, String name) async {
    final savedAs = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PlanEditorScreen(planName: name, isNew: false)),
    );
    ref.invalidate(planListProvider);
    if (savedAs != null) {
      ref.invalidate(planProvider(name));
      ref.invalidate(planProvider(savedAs));
      final selected = ref.read(selectedPlanNameProvider);
      if (selected == name && savedAs != name) {
        ref.read(selectedPlanNameProvider.notifier).select(savedAs);
      }
    }
  }

  Future<void> _duplicatePlan(BuildContext context, WidgetRef ref, String name) async {
    final controller = TextEditingController(text: 'Copy of $name');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Duplicate Plan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New plan name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !context.mounted) return;

    final exists = await PlanService.planExists(newName);
    if (!context.mounted) return;

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A plan named "$newName" already exists')),
      );
      return;
    }

    final stages = await PlanService.loadPlan(name);
    await PlanService.savePlan(newName, stages);
    ref.invalidate(planListProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PlanService.deletePlan(name);
      final selected = ref.read(selectedPlanNameProvider);
      if (selected == name) {
        ref.read(selectedPlanNameProvider.notifier).select('default');
      }
      ref.invalidate(planListProvider);
    }
  }

  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final inputName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('New Plan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Plan name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (inputName == null || inputName.isEmpty || !context.mounted) return;

    final exists = await PlanService.planExists(inputName);
    if (!context.mounted) return;

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A plan named "$inputName" already exists')),
      );
      return;
    }

    final savedAs = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(planName: inputName, isNew: true),
      ),
    );
    ref.invalidate(planListProvider);
    if (savedAs != null) {
      ref.invalidate(planProvider(savedAs));
    }
  }
}
