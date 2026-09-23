import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'sqlite_sync_store.dart';
import 'sync_gateway.dart';
import 'sync_models.dart';

final class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  SyncController({
    required SqliteSyncStore localStore,
    required SyncGateway? gateway,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  })  : _localStore = localStore,
        _gateway = gateway,
        _connectivityChanges = connectivityChanges;

  final SqliteSyncStore _localStore;
  final SyncGateway? _gateway;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounce;
  String? _nickname;
  DateTime? _lastSuccess;
  SyncPhase _phase = SyncPhase.disconnected;
  String? _errorMessage;
  bool _initialized = false;
  bool _syncing = false;
  bool _rerunRequested = false;
  int _dataRevision = 0;

  String? get nickname => _nickname;
  DateTime? get lastSuccess => _lastSuccess;
  SyncPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _gateway != null;
  int get dataRevision => _dataRevision;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _nickname = _localStore.readNickname();
    _lastSuccess = _localStore.readLastSuccess();
    _phase = _nickname == null
        ? SyncPhase.disconnected
        : (_gateway == null ? SyncPhase.unavailable : SyncPhase.idle);
    WidgetsBinding.instance.addObserver(this);
    final stream = _connectivityChanges ?? Connectivity().onConnectivityChanged;
    _connectivitySubscription = stream.listen(_onConnectivityChanged);
    notifyListeners();
    if (_nickname != null && _gateway != null) unawaited(syncNow());
  }

  Future<bool> connect(String value) async {
    final normalized = normalizeNickname(value);
    if (!isValidNickname(normalized)) {
      throw const FormatException('Invalid nickname.');
    }
    if (_gateway == null) {
      _phase = SyncPhase.unavailable;
      _errorMessage = 'Supabase is not configured.';
      notifyListeners();
      return false;
    }
    _localStore.saveNickname(normalized);
    _nickname = normalized;
    _phase = SyncPhase.idle;
    _errorMessage = null;
    notifyListeners();
    await syncNow();
    return _phase == SyncPhase.synced;
  }

  Future<void> disconnect() async {
    _debounce?.cancel();
    _localStore.clearNickname();
    _nickname = null;
    _lastSuccess = null;
    _phase = SyncPhase.disconnected;
    _errorMessage = null;
    notifyListeners();
  }

  void scheduleSync() {
    if (_nickname == null || _gateway == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), syncNow);
  }

  Future<void> syncNow() async {
    final nickname = _nickname;
    final gateway = _gateway;
    if (nickname == null) return;
    if (gateway == null) {
      _phase = SyncPhase.unavailable;
      notifyListeners();
      return;
    }
    if (_syncing) {
      _rerunRequested = true;
      return;
    }

    _syncing = true;
    _phase = SyncPhase.syncing;
    _errorMessage = null;
    notifyListeners();
    try {
      final localPayload = _localStore.buildPayload();
      final mergedPayload = await gateway.synchronize(
        nickname: nickname,
        localPayload: localPayload,
      );
      _localStore.mergePayload(mergedPayload);
      final now = DateTime.now().toUtc();
      _localStore.saveLastSuccess(now);
      _lastSuccess = now;
      _phase = SyncPhase.synced;
      _dataRevision++;
    } catch (error) {
      _phase = SyncPhase.error;
      _errorMessage = error.toString();
    } finally {
      _syncing = false;
      notifyListeners();
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(syncNow());
      }
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      scheduleSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) scheduleSync();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connectivitySubscription?.cancel();
    if (_initialized) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
