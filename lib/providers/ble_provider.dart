import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';
import 'app_providers.dart';

enum BleStatus { idle, connecting, connected, disconnected }

class BleConnectionState {
  final BleStatus status;
  final int? currentBpm;
  final int? batteryLevel;

  const BleConnectionState({
    this.status = BleStatus.idle,
    this.currentBpm,
    this.batteryLevel,
  });
}

class BleConnectionNotifier extends StateNotifier<BleConnectionState> {
  BleConnectionNotifier(this._ref) : super(const BleConnectionState()) {
    _init();
  }

  final Ref _ref;
  BleService? _service;
  StreamSubscription<HeartRateData>? _hrSub;
  StreamSubscription<bool>? _connSub;
  bool _disposed = false;
  String? _savedAddress;

  BleService? get service => _service;

  Future<void> _init() async {
    final config = await _ref.read(configProvider.future);
    _savedAddress = config.savedDeviceAddress;
    if (_savedAddress != null && !_disposed) _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _savedAddress == null) return;
    if (state.status == BleStatus.connecting) return;

    state = BleConnectionState(status: BleStatus.connecting);

    try {
      // Create the service once; reuse it across reconnects so subscribers
      // (e.g. ActiveSessionScreen) never hold a stale stream reference.
      _service ??= BleService();

      _hrSub ??= _service!.hrStream.listen((data) {
        if (!_disposed) {
          state = BleConnectionState(
            status: BleStatus.connected,
            currentBpm: data.bpm,
            batteryLevel: state.batteryLevel,
          );
        }
      });

      _connSub ??= _service!.connectionStream.listen((connected) {
        if (_disposed) return;
        if (!connected) {
          state = BleConnectionState(status: BleStatus.disconnected);
          Future.delayed(const Duration(seconds: 5), () {
            if (!_disposed && state.status == BleStatus.disconnected) _connect();
          });
        }
      });

      final devices = await BleService.scan(timeout: const Duration(seconds: 15));
      if (_disposed) return;

      final device = devices.firstWhere(
        (d) => d.address == _savedAddress,
        orElse: () => throw Exception('Device not found in scan'),
      );

      final battery = await _service!.connect(device);
      if (_disposed) return;

      state = BleConnectionState(
        status: BleStatus.connected,
        batteryLevel: battery,
      );
    } catch (_) {
      if (!_disposed) {
        state = BleConnectionState(status: BleStatus.disconnected);
        Future.delayed(const Duration(seconds: 10), () {
          if (!_disposed && state.status == BleStatus.disconnected) _connect();
        });
      }
    }
  }

  /// Waits until the provider reaches [BleStatus.connected].
  /// Throws if [timeout] elapses first.
  Future<void> waitForConnection({required Duration timeout}) async {
    if (state.status == BleStatus.connected) return;

    final completer = Completer<void>();
    final sub = stream.listen((s) {
      if (s.status == BleStatus.connected && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      sub.cancel();
      throw Exception('HR monitor not found within ${timeout.inSeconds}s');
    }
    sub.cancel();
  }

  /// Call after the user selects a different device from the scanner.
  void refreshDevice(String address) {
    _savedAddress = address;
    _hrSub?.cancel();
    _connSub?.cancel();
    _hrSub = null;
    _connSub = null;
    _service?.disconnect();
    _service?.dispose();
    _service = null;
    state = const BleConnectionState();
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _hrSub?.cancel();
    _connSub?.cancel();
    _service?.disconnect();
    _service?.dispose();
    super.dispose();
  }
}

final bleConnectionProvider =
    StateNotifierProvider<BleConnectionNotifier, BleConnectionState>((ref) {
  return BleConnectionNotifier(ref);
});
