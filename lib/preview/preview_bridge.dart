// lib/preview/preview_bridge.dart
//
// Turns inbound messages into controller calls, and preview events into
// outbound messages.
//
// Every handler is defensive about shape. The admin and the preview are built
// and deployed separately, so at any moment one may be a version ahead — an
// unknown message type, or a known one carrying a field that does not exist
// yet, must be ignored rather than crash the frame. A preview that goes blank
// on a version skew is worse than one that briefly ignores a new control.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/home_feed_models.dart';
import 'bridge/bridge_stub.dart' if (dart.library.html) 'bridge/bridge_web.dart';
import 'preview_controller.dart';
import 'preview_protocol.dart';
import 'preview_state.dart';

class PreviewBridge {
  final Ref _ref;
  final PreviewChannel _channel;

  PreviewBridge(this._ref, {PreviewChannel? channel})
      : _channel = channel ?? PreviewChannel();

  PreviewController get _controller => _ref.read(previewControllerProvider.notifier);

  void start() => _channel.listen(_handle);

  void dispose() => _channel.dispose();

  // ---- inbound ----

  void _handle(Map<String, dynamic> message) {
    final type = message['type'] as String;
    final payload = (message['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

    switch (type) {
      case PreviewInbound.setFeed:
        _controller.setFeed(HomeFeed.fromJson(payload));

      case PreviewInbound.patchSection:
        final raw = payload['section'];
        if (raw is Map) {
          _controller.patchSection(HomeSection.fromJson(Map<String, dynamic>.from(raw)));
        }

      case PreviewInbound.setContext:
        _controller.setContext(PreviewContext.fromJson(payload));

      case PreviewInbound.setDevice:
        _controller.setDevice(DeviceSpec.fromJson(payload));

      case PreviewInbound.setNetwork:
        _controller.setNetwork(NetworkProfile.byId(payload['id']?.toString()));

      case PreviewInbound.setDebug:
        _controller.setDebug(DebugFlags.fromJson(payload));

      case PreviewInbound.setClock:
        final iso = payload['instant']?.toString();
        _controller.setClock(iso == null ? null : DateTime.tryParse(iso));

      case PreviewInbound.selectSection:
        _controller.select(payload['id']?.toString());

      case PreviewInbound.refresh:
        _controller.refresh();

      default:
        // A control this build predates. Ignored, deliberately.
        break;
    }
  }

  // ---- outbound ----

  /// A tap inside the preview, so the admin can highlight the matching row.
  void reportTap({required String sectionId, required String sectionType}) {
    _channel.send(PreviewOutbound.sectionTapped, {
      'id': sectionId,
      'type': sectionType,
    });
  }

  /// Where a tap would have navigated. The preview does not follow it — losing
  /// the home screen mid-edit would be worse than not seeing the destination —
  /// so the admin surfaces the route instead.
  void reportNavigation(String route) {
    _channel.send(PreviewOutbound.navigation, {'route': route});
  }

  void reportMetrics({
    required String sectionId,
    required int buildMicros,
    String? cacheStatus,
  }) {
    _channel.send(PreviewOutbound.metrics, {
      'id': sectionId,
      'build_micros': buildMicros,
      if (cacheStatus != null) 'cache_status': cacheStatus,
    });
  }

  void reportSectionError({required String sectionId, required String message}) {
    _channel.send(PreviewOutbound.sectionError, {
      'id': sectionId,
      'message': message,
    });
  }
}

final previewBridgeProvider = Provider<PreviewBridge>((ref) {
  final bridge = PreviewBridge(ref);
  ref.onDispose(bridge.dispose);
  return bridge;
});
