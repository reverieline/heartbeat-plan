import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../providers/ble_provider.dart';
import 'device_scanner_screen.dart';
import 'active_session_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final plans = ref.watch(planListProvider);
    final selectedPlan = ref.watch(selectedPlanNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RHR Trainer'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
          }),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DeviceCard(config: config),
            const SizedBox(height: 12),
            const _HrIndicatorCard(),
            const SizedBox(height: 12),
            _PlanCard(plans: plans, selectedPlan: selectedPlan, ref: ref),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: config.when(
                data: (cfg) => cfg.isConfigured
                    ? () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ActiveSessionScreen()))
                    : null,
                loading: () => null,
                error: (_, _) => null,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrIndicatorCard extends ConsumerWidget {
  const _HrIndicatorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleConnectionProvider);

    return switch (ble.status) {
      BleStatus.idle => const SizedBox.shrink(),
      BleStatus.connecting => Card(
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: const Text('Connecting to HR monitor…'),
        ),
      ),
      BleStatus.connected => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.favorite, color: Theme.of(context).colorScheme.error, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Heart Rate',
                        style: Theme.of(context).textTheme.labelMedium),
                    Text(
                      ble.currentBpm != null ? '${ble.currentBpm} bpm' : '— bpm',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (ble.batteryLevel != null)
                Column(
                  children: [
                    const Icon(Icons.battery_full, size: 18),
                    Text('${ble.batteryLevel}%',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
            ],
          ),
        ),
      ),
      BleStatus.disconnected => Card(
        child: ListTile(
          leading: Icon(Icons.bluetooth_disabled,
              color: Theme.of(context).colorScheme.error),
          title: const Text('HR monitor disconnected'),
          subtitle: const Text('Reconnecting…'),
        ),
      ),
    };
  }
}

class _DeviceCard extends StatelessWidget {
  final AsyncValue<dynamic> config;
  const _DeviceCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth),
        title: config.when(
          data: (cfg) => Text(cfg.savedDeviceName ?? 'No device selected'),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Error'),
        ),
        subtitle: config.when(
          data: (cfg) => Text(cfg.savedDeviceAddress ?? 'Tap to scan for HR monitors'),
          loading: () => null,
          error: (_, _) => null,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeviceScannerScreen()),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final AsyncValue<List<String>> plans;
  final String selectedPlan;
  final WidgetRef ref;

  const _PlanCard({required this.plans, required this.selectedPlan, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text('Plan: $selectedPlan'),
        subtitle: plans.when(
          data: (list) => Text('${list.length} plan(s) available'),
          loading: () => const Text('Loading plans...'),
          error: (_, _) => const Text('No plans'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPlanPicker(context),
      ),
    );
  }

  void _showPlanPicker(BuildContext context) {
    final list = plans.value ?? [];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(list[i]),
          selected: list[i] == selectedPlan,
          onTap: () {
            ref.read(selectedPlanNameProvider.notifier).state = list[i];
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
