// lib/preview/bridge/bridge_web.dart
//
// postMessage transport between the admin panel and this frame.
//
// Chosen over a WebSocket for the editing loop on purpose: the admin already
// holds the draft in memory, so a round trip to the server to see your own
// keystroke would add latency for nothing. A socket is still the right
// transport for changes originating elsewhere — a colleague publishing, or a
// preview opened on a real handset — and that path is additive: it delivers
// the same messages this file already understands.

import 'dart:async';
import 'dart:convert';
// The lint guards against web-only imports leaking into a mobile build. This
// file is reachable only through the conditional import in preview_bridge.dart
// and only compiles for web, which is precisely the exemption it describes.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../preview_protocol.dart';

typedef PreviewMessageHandler = void Function(Map<String, dynamic> message);

class PreviewChannel {
  StreamSubscription<html.MessageEvent>? _subscription;

  /// The admin origin, passed as `?parentOrigin=` when the iframe is built.
  ///
  /// Both directions are pinned to it. Outbound this matters most: the draft
  /// layout, store codes and mock profiles all travel over this channel, and
  /// posting to `*` would hand them to whatever page managed to embed the
  /// preview. Inbound it stops a hostile frame from driving the preview.
  final String? _parentOrigin;

  PreviewChannel({String? parentOrigin})
      : _parentOrigin =
            parentOrigin ?? html.window.location.search?.let(_originFromQuery);

  void listen(PreviewMessageHandler onMessage) {
    previewLog('listening; parent origin '
        '${_parentOrigin ?? "not pinned — running standalone, nothing will be sent"}');

    _subscription = html.window.onMessage.listen((event) {
      if (_parentOrigin != null && event.origin != _parentOrigin) {
        // Silent by design, which makes a mismatched origin very hard to spot
        // from the outside — so say so, but only for traffic aimed at us.
        if (event.data is Map && (event.data as Map)['channel'] == kPreviewChannel) {
          previewLog('IGNORED a preview message from ${event.origin}, '
              'expected $_parentOrigin — check the parentOrigin query parameter');
        }
        return;
      }

      final data = event.data;
      if (data is! Map) return;

      // An iframe receives messages from anything on the page — browser
      // extensions and dev tooling among them — so unaddressed traffic is
      // dropped without inspection.
      if (data['channel'] != kPreviewChannel) return;

      final type = data['type'];
      if (type is! String) return;

      previewLog('received $type');

      // Deep-converted, not `Map<String, dynamic>.from`: that is shallow, so
      // nested maps stay dynamic-keyed and every model parser drops them.
      onMessage({
        'type': type,
        'payload': normalisePayload(data['payload']),
      });
    });

    previewLog('sending preview_ready');
    send(PreviewOutbound.ready, {'protocol_version': kPreviewProtocolVersion});
  }

  void send(String type, Map<String, dynamic> payload) {
    final parent = html.window.parent;
    if (parent == null) return;

    final message = {
      'channel': kPreviewChannel,
      'protocol_version': kPreviewProtocolVersion,
      'type': type,
      'payload': payload,
    };

    // Serialised through JSON so what the admin receives is a plain object
    // rather than a Dart-flavoured one whose maps it cannot index.
    final encoded = jsonDecode(jsonEncode(message));

    // With no pinned origin the preview is running standalone (a developer
    // opening the build directly), where there is no parent to talk to and
    // nothing worth broadcasting.
    if (_parentOrigin == null) return;

    parent.postMessage(encoded, _parentOrigin);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Console output, prefixed so it reads alongside the admin panel's own
/// `[preview]` lines in the same devtools console.
///
/// Goes to `window.console` rather than `print`: `print` on web is routed
/// through the Dart runtime and is banned by the analyzer's `avoid_print`,
/// and this needs to be readable in the browser next to the panel's logs.
void previewLog(String message) => html.window.console.log('[preview:flutter] $message');

String? _originFromQuery(String search) {
  if (search.isEmpty) return null;
  final value = Uri.splitQueryString(
    search.startsWith('?') ? search.substring(1) : search,
  )['parentOrigin'];
  return (value == null || value.isEmpty) ? null : value;
}

extension _Let<T> on T {
  R? let<R>(R? Function(T) block) => block(this);
}
