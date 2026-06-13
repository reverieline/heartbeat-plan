import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HeartRateData {
  final int bpm;
  final bool? sensorContact;
  final List<double> rrIntervalsMs;

  const HeartRateData({
    required this.bpm,
    this.sensorContact,
    this.rrIntervalsMs = const [],
  });
}

class BleDevice {
  final BluetoothDevice device;
  final String name;
  final String address;

  BleDevice({required this.device, required this.name, required this.address});
}

class BleService {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _hrSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  final _hrController = StreamController<HeartRateData>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<HeartRateData> get hrStream => _hrController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  static Future<List<BleDevice>> scan({Duration timeout = const Duration(seconds: 15)}) async {
    final found = <BleDevice>[];
    final seen = <String>{};

    // Subscribe BEFORE startScan — scanResults is a broadcast stream that never closes,
    // so we must collect during the scan, not after it.
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (seen.contains(r.device.remoteId.str)) continue;
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : '';
        if (name.isEmpty) continue; // skip truly anonymous devices
        seen.add(r.device.remoteId.str);
        found.add(BleDevice(
          device: r.device,
          name: name,
          address: r.device.remoteId.str,
        ));
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      // startScan is non-blocking; the timeout schedules an internal stopScan.
      // Wait the full duration so the listener collects results.
      await Future.delayed(timeout);
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }

    return found;
  }

  Future<int?> connect(BleDevice device) async {
    _connectedDevice = device.device;
    await device.device.connect(autoConnect: false);
    _connectionController.add(true);

    // Cancel previous subscription so reconnects don't stack up listeners.
    await _connStateSub?.cancel();
    _connStateSub = device.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connectionController.add(false);
      }
    });

    final services = await device.device.discoverServices();
    int? battery;

    for (final service in services) {
      final sid = service.uuid.toString().toLowerCase();
      if (sid.contains('180d')) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase().contains('2a37')) {
            await char.setNotifyValue(true);
            _hrSub = char.lastValueStream.listen((data) {
              final parsed = _parseHrMeasurement(data);
              if (parsed != null) _hrController.add(parsed);
            });
          }
        }
      }
      if (sid.contains('180f')) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase().contains('2a19')) {
            final val = await char.read();
            if (val.isNotEmpty) battery = val[0];
          }
        }
      }
    }

    return battery;
  }

  Future<void> disconnect() async {
    await _hrSub?.cancel();
    await _connStateSub?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  static HeartRateData? _parseHrMeasurement(List<int> data) {
    if (data.isEmpty) return null;
    final flags = data[0];
    final hr16bit = (flags & 0x01) != 0;
    final sensorContact = (flags & 0x06) == 0x06 ? true : (flags & 0x04) != 0 ? false : null;

    int bpm;
    int offset;
    if (hr16bit) {
      if (data.length < 3) return null;
      bpm = data[1] | (data[2] << 8);
      offset = 3;
    } else {
      if (data.length < 2) return null;
      bpm = data[1];
      offset = 2;
    }

    final energyPresent = (flags & 0x08) != 0;
    if (energyPresent) offset += 2;

    final rrPresent = (flags & 0x10) != 0;
    final rrIntervals = <double>[];
    if (rrPresent) {
      while (offset + 1 < data.length) {
        final raw = data[offset] | (data[offset + 1] << 8);
        rrIntervals.add(raw / 1024.0 * 1000.0);
        offset += 2;
      }
    }

    return HeartRateData(bpm: bpm, sensorContact: sensorContact, rrIntervalsMs: rrIntervals);
  }

  void dispose() {
    _hrSub?.cancel();
    _connStateSub?.cancel();
    _hrController.close();
    _connectionController.close();
  }
}
