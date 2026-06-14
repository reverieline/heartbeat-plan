import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_providers.dart';
import '../providers/ble_provider.dart';
import '../services/ble_service.dart';

class DeviceScannerScreen extends ConsumerStatefulWidget {
  const DeviceScannerScreen({super.key});

  @override
  ConsumerState<DeviceScannerScreen> createState() => _DeviceScannerScreenState();
}

class _DeviceScannerScreenState extends ConsumerState<DeviceScannerScreen> {
  List<BleDevice> _devices = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _error = null; _devices = []; });
    try {
      await _requestPermissions();
      final results = await BleService.scan(timeout: const Duration(seconds: 15));
      if (mounted) setState(() { _devices = results; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _scanning = false; });
    }
  }

  Future<void> _selectDevice(BleDevice device) async {
    final config = await ref.read(configProvider.future);
    await config.saveDevice(device.address, device.name);
    ref.invalidate(configProvider);
    // Kick the global connection manager to connect to the newly selected device.
    ref.read(bleConnectionProvider.notifier).refreshDevice(device.address);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select HR Monitor'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _error != null
          ? Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _startScan, child: const Text('Retry')),
              ],
            ))
          : _devices.isEmpty
              ? Center(child: Text(_scanning ? 'Scanning...' : 'No HR monitors found'))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    return ListTile(
                      leading: d.advertisesHr
                          ? const Icon(Icons.favorite, color: Colors.redAccent)
                          : const Icon(Icons.bluetooth),
                      title: Text(d.name),
                      subtitle: Text(d.address),
                      onTap: () => _selectDevice(d),
                    );
                  },
                ),
      ),
    );
  }
}
