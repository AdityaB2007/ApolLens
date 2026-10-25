// Gavin - Track acknowledged session saves without claiming offline success.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/repair_session.dart';

final class SessionReceipt {
  const SessionReceipt(this.sessionId, this.revision);
  final String sessionId;
  final int revision;
}

// The adapter must make each session/revision idempotent and reject stale writes.
typedef SessionWriter =
    Future<SessionReceipt> Function(RepairSession session, Future<void> cancel);

enum SessionSaveStatus { offline, saving, saved, failed }

final class SessionSaveState {
  const SessionSaveState._(this.status, [this.session]);
  static const empty = SessionSaveState._(SessionSaveStatus.offline);
  final SessionSaveStatus status;
  final RepairSession? session;
}

final class SessionService extends ValueNotifier<SessionSaveState> {
  SessionService({this.write}) : super(SessionSaveState.empty);

  final SessionWriter? write;
  Completer<void>? _request;
  int _generation = 0;
  bool _disposed = false;

  void _cancel() {
    final request = _request;
    _request = null;
    if (request != null && !request.isCompleted) request.complete();
  }

  Future<void> save(RepairSession session) {
    final previous = value.session;
    if (_disposed ||
        (previous?.id == session.id &&
            session.revision <= previous!.revision)) {
      return Future.value();
    }
    return _save(session);
  }

  Future<void> retry() {
    final session = value.session;
    if (_disposed ||
        session == null ||
        value.status != SessionSaveStatus.failed) {
      return Future.value();
    }
    return _save(session);
  }

  Future<void> _save(RepairSession session) async {
    _cancel();
    final generation = ++_generation;
    final writer = write;
    if (writer == null) {
      value = SessionSaveState._(SessionSaveStatus.offline, session);
      return;
    }
    final request = _request = Completer<void>();
    value = SessionSaveState._(SessionSaveStatus.saving, session);
    if (_disposed || generation != _generation) return;
    try {
      final receipt = await Future.any<SessionReceipt?>([
        writer(session, request.future),
        request.future.then((_) => null),
      ]).timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) return;
      if (receipt?.sessionId != session.id ||
          receipt?.revision != session.revision) {
        throw StateError(
          'Session acknowledgement does not match the revision.',
        );
      }
      value = SessionSaveState._(SessionSaveStatus.saved, session);
    } catch (_) {
      if (!_disposed && generation == _generation) {
        value = SessionSaveState._(SessionSaveStatus.failed, session);
      }
    } finally {
      if (generation == _generation) _cancel();
    }
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _cancel();
    value = SessionSaveState.empty;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancel();
    super.dispose();
  }
}
