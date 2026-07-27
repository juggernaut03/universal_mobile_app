// lib/preview/bridge/bridge_stub.dart
//
// Non-web implementation. Exists so the preview tree compiles and can be
// unit-tested off a browser; on mobile nothing reaches it, because nothing in
// the shipping app imports lib/preview.

typedef PreviewMessageHandler = void Function(Map<String, dynamic> message);

class PreviewChannel {
  const PreviewChannel();

  /// No parent frame off the web, so nothing ever arrives.
  void listen(PreviewMessageHandler onMessage) {}

  void send(String type, Map<String, dynamic> payload) {}

  void dispose() {}
}
