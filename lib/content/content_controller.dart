import 'package:flutter/foundation.dart';

import '../grammar/grammar_catalog.dart';
import 'content_bundle.dart';
import 'content_gateway.dart';
import 'content_manifest.dart';
import 'content_store.dart';

enum ContentUpdatePhase {
  idle,
  checking,
  upToDate,
  updated,
  unavailable,
  incompatible,
  error,
}

final class ContentController extends ChangeNotifier {
  ContentController({
    required ContentBundle bundled,
    required ContentStore store,
    ContentGateway? gateway,
  })  : _bundled = bundled,
        _active = bundled,
        _store = store,
        _gateway = gateway;

  final ContentBundle _bundled;
  ContentBundle _active;
  final ContentStore _store;
  final ContentGateway? _gateway;
  bool _launchCheckStarted = false;
  Future<void>? _currentCheck;

  ContentUpdatePhase phase = ContentUpdatePhase.idle;
  DateTime? lastCheckedAt;
  Object? lastError;

  GrammarCatalog get catalog => _active.catalog;
  ContentManifest get manifest => _active.manifest;
  bool get isBundled => identical(_active, _bundled);
  bool get isConfigured => _gateway != null;

  Future<void> initialize() async {
    final local = await _store.loadActive();
    if (local != null &&
        !local.manifest.publishedAt.isBefore(_bundled.manifest.publishedAt)) {
      _active = local;
    }
  }

  Future<void> checkOnLaunch() {
    if (_launchCheckStarted) return _currentCheck ?? Future<void>.value();
    _launchCheckStarted = true;
    return checkNow();
  }

  Future<void> checkNow() {
    final running = _currentCheck;
    if (running != null) return running;
    final future = _performCheck();
    _currentCheck = future;
    return future.whenComplete(() => _currentCheck = null);
  }

  Future<void> _performCheck() async {
    final gateway = _gateway;
    if (gateway == null) {
      phase = ContentUpdatePhase.unavailable;
      notifyListeners();
      return;
    }
    phase = ContentUpdatePhase.checking;
    lastError = null;
    notifyListeners();
    try {
      final remote = await gateway.fetchManifest();
      lastCheckedAt = DateTime.now().toUtc();
      if (!remote.isCompatible) {
        phase = ContentUpdatePhase.incompatible;
        notifyListeners();
        return;
      }
      if (remote.contentVersion == manifest.contentVersion &&
          remote.sha256 == manifest.sha256) {
        phase = ContentUpdatePhase.upToDate;
        notifyListeners();
        return;
      }
      final bytes = await gateway.fetchBundle(remote);
      _active = await _store.install(remote, bytes);
      phase = ContentUpdatePhase.updated;
      notifyListeners();
    } on Object catch (error) {
      lastCheckedAt = DateTime.now().toUtc();
      lastError = error;
      phase = ContentUpdatePhase.error;
      notifyListeners();
    }
  }
}
