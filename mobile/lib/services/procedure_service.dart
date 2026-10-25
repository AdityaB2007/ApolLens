// Gavin - Look up supplied manuals for an exact recognized item in ApolLens.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/repair_procedure.dart';

typedef ProcedureLookup =
    Future<RepairProcedure?> Function(String itemId, Future<void> cancel);

enum ProcedureStatus { unavailable, loading, unsupported, ready, failed }

final class ProcedureState {
  const ProcedureState._(this.status, [this.itemId, this.procedure]);
  static const unavailable = ProcedureState._(ProcedureStatus.unavailable);

  final ProcedureStatus status;
  final String? itemId;
  final RepairProcedure? procedure;
}

final class ProcedureService extends ValueNotifier<ProcedureState> {
  ProcedureService({this.lookup}) : super(ProcedureState.unavailable);

  // Indi supplies the adapter; there is no assumed procedure endpoint.
  final ProcedureLookup? lookup;
  Completer<void>? _request;
  int _generation = 0;
  bool _disposed = false;

  void _cancel() {
    final request = _request;
    _request = null;
    if (request != null && !request.isCompleted) request.complete();
  }

  Future<void> load(String? itemId, {bool retry = false}) async {
    if (_disposed) return;
    final find = lookup;
    if (find == null ||
        itemId == null ||
        itemId.trim().isEmpty ||
        itemId != itemId.trim()) {
      reset();
      return;
    }
    // Repeated frames do not repeatedly fetch the same manual, even on failure.
    if (!retry && value.itemId == itemId) return;
    _cancel();
    final generation = ++_generation;
    final request = _request = Completer<void>();
    value = ProcedureState._(ProcedureStatus.loading, itemId);
    if (_disposed || generation != _generation) return;
    try {
      final procedure = await Future.any([
        find(itemId, request.future),
        request.future.then<RepairProcedure?>((_) => null),
      ]).timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) return;
      if (procedure != null && !procedure.supports(itemId)) {
        throw StateError('Returned procedure does not match the item.');
      }
      value = ProcedureState._(
        procedure == null ? ProcedureStatus.unsupported : ProcedureStatus.ready,
        itemId,
        procedure,
      );
    } catch (_) {
      if (!_disposed && generation == _generation) {
        value = ProcedureState._(ProcedureStatus.failed, itemId);
      }
    } finally {
      if (generation == _generation) _cancel();
    }
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _cancel();
    value = ProcedureState.unavailable;
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
