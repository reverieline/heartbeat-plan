import 'package:flutter/material.dart';
import '../models/session_log.dart';
import '../models/hr_zone.dart';
import '../models/user_profile.dart';

class SummaryScreen extends StatefulWidget {
  final SessionLog log;
  final UserProfile profile;

  const SummaryScreen({super.key, required this.log, required this.profile});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late TrainingSummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = _buildSummary();
  }

  TrainingSummary _buildSummary() {
    final zones = buildZones(widget.profile);
    final bpmSamples = widget.log.events
        .where((e) => e.kind == LogEventKind.bpm && e.bpm != null)
        .map((e) => (e.timestamp, e.bpm!))
        .toList();

    final zoneSeconds = {for (final z in zones) z: 0.0};
    for (int i = 1; i < bpmSamples.length; i++) {
      final dt = bpmSamples[i].$1.difference(bpmSamples[i - 1].$1).inMilliseconds / 1000.0;
      if (dt <= 0 || dt > 10) continue;
      final bpm = bpmSamples[i].$2;
      if (bpm <= 0 || bpmSamples[i - 1].$2 <= 0) continue;
      for (final z in zones) {
        if (z.contains(bpm)) {
          zoneSeconds[z] = (zoneSeconds[z] ?? 0) + dt;
          break;
        }
      }
    }

    final tracked = zoneSeconds.values.fold(0.0, (a, b) => a + b);
    final calories = estimateCalories(bpmSamples: bpmSamples, profile: widget.profile);

    return TrainingSummary(
      totalDuration: widget.log.duration,
      trackedDuration: Duration(seconds: tracked.round()),
      zoneSummaries: zones.map((z) => ZoneSummary(
        zone: z,
        duration: Duration(seconds: (zoneSeconds[z] ?? 0).round()),
      )).toList(),
      caloriesBurned: calories,
      zoneMethod: 'Karvonen',
      calorieMethod: 'Keytel',
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Summary')),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _Row('Total Time', _fmtDuration(_summary.totalDuration)),
                  _Row('Tracked HR', _fmtDuration(_summary.trackedDuration)),
                  _Row('Calories', '${_summary.caloriesBurned.round()} kcal'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Heart Rate Zones (${_summary.zoneMethod})',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ..._summary.zoneSummaries.map((zs) => _ZoneRow(summary: zs,
                      total: _summary.trackedDuration)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reference HR Zones',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Resting ${widget.profile.restingHr} bpm · Max ${widget.profile.maxHr} bpm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ..._summary.zoneSummaries.map(
                    (zs) => _Row(zs.zone.name, zs.zone.description),
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final ZoneSummary summary;
  final Duration total;
  const _ZoneRow({required this.summary, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total.inSeconds > 0
        ? summary.duration.inSeconds / total.inSeconds
        : 0.0;
    final m = summary.duration.inMinutes;
    final s = summary.duration.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(summary.zone.name),
              Text('${m}m ${s}s (${(pct * 100).round()}%)'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: pct.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}
