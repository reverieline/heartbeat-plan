import 'dart:io';
import 'package:flutter/material.dart';
import '../models/session_log.dart';
import '../models/hr_zone.dart';
import '../models/user_profile.dart';

class SummaryScreen extends StatefulWidget {
  final SessionLog log;
  final UserProfile profile;
  final List<File>? allLogs;
  final int initialIndex;

  const SummaryScreen({
    super.key,
    required this.log,
    required this.profile,
    this.allLogs,
    this.initialIndex = 0,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late TrainingSummary _summary;
  PageController? _pageController;
  int _currentIndex = 0;
  final Map<int, SessionLog?> _pageCache = {};
  final Set<int> _loading = {};

  @override
  void initState() {
    super.initState();
    if (widget.allLogs == null) {
      _summary = _buildSummary(widget.log);
    } else {
      _currentIndex = widget.initialIndex;
      _pageController = PageController(initialPage: widget.initialIndex);
      _pageCache[widget.initialIndex] = widget.log;
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int index) async {
    if (_pageCache.containsKey(index) || _loading.contains(index)) return;
    _loading.add(index);
    try {
      final content = await widget.allLogs![index].readAsString();
      final log = SessionLog.fromText(content);
      if (mounted) {
        setState(() {
          _pageCache[index] = log;
          _loading.remove(index);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pageCache[index] = null;
          _loading.remove(index);
        });
      }
    }
  }

  TrainingSummary _buildSummary(SessionLog log) {
    final zones = buildZones(widget.profile);
    final bpmSamples = log.events
        .where((e) => e.kind == LogEventKind.bpm && e.bpm != null)
        .map((e) => (e.timestamp, e.bpm!))
        .toList();

    final zoneSeconds = {for (final z in zones) z: 0.0};
    for (int i = 1; i < bpmSamples.length; i++) {
      final dt = bpmSamples[i].$1
              .difference(bpmSamples[i - 1].$1)
              .inMilliseconds /
          1000.0;
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
    final calories =
        estimateCalories(bpmSamples: bpmSamples, profile: widget.profile);

    return TrainingSummary(
      totalDuration: log.duration,
      trackedDuration: Duration(seconds: tracked.round()),
      zoneSummaries: zones
          .map((z) => ZoneSummary(
                zone: z,
                duration:
                    Duration(seconds: (zoneSeconds[z] ?? 0).round()),
              ))
          .toList(),
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

  String _formatTitle(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  Widget _buildSummaryBody(TrainingSummary summary) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _Row('Total Time', _fmtDuration(summary.totalDuration)),
                _Row('Tracked HR', _fmtDuration(summary.trackedDuration)),
                _Row('Calories', '${summary.caloriesBurned.round()} kcal'),
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
                Text('Heart Rate Zones (${summary.zoneMethod})',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...summary.zoneSummaries.map((zs) =>
                    _ZoneRow(summary: zs, total: summary.trackedDuration)),
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
                ...summary.zoneSummaries
                    .map((zs) => _Row(zs.zone.name, zs.zone.description)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allLogs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_formatTitle(widget.log.startTime))),
        body: SafeArea(top: false, child: _buildSummaryBody(_summary)),
      );
    }

    final currentLog = _pageCache[_currentIndex];
    final title =
        currentLog != null ? _formatTitle(currentLog.startTime) : '…';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.allLogs!.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (_, i) {
            if (!_pageCache.containsKey(i)) {
              _loadPage(i);
              return const Center(child: CircularProgressIndicator());
            }
            final log = _pageCache[i];
            if (log == null) {
              return const Center(child: Text('Could not load session'));
            }
            return _buildSummaryBody(_buildSummary(log));
          },
        ),
      ),
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
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
