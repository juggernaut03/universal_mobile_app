import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../main.dart' show navigatorKey;

/// Handles incoming Android App Links / iOS Universal Links from
/// `ecomadmin.shalviadvision.com/<projectcode>[/...]` (the public promo
/// page, see Universal_admin_panel's public-promo-page.tsx). Each tenant's app
/// only ever receives links under its own project code — enforced by the
/// Android manifest's per-flavor pathPrefix and the hosted
/// apple-app-site-association's per-app paths — so no project-code check is
/// needed here, just the sub-path.
///
/// Navigation goes through [navigatorKey], the same global key
/// FirebaseNotificationService._handleMessageNavigation already uses to call
/// `context.go(route)` from outside the widget tree.
class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();

  /// Call once from main.dart, after the first frame so [navigatorKey] has a
  /// mounted context to navigate with.
  static Future<void> initialize() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _navigate(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: failed to read initial link: $e');
    }

    _appLinks.uriLinkStream.listen(
      _navigate,
      onError: (e) => debugPrint('DeepLinkService: link stream error: $e'),
    );
  }

  /// `/RET2690` (just the promo page itself) -> home. `/RET2690/product/123`
  /// -> `/product/123`, reusing whatever path segments follow the project
  /// code as-is — the promo page doesn't link to anything more specific than
  /// its own root today, but this means it can start to without an app
  /// update once it does.
  static void _navigate(Uri uri) {
    try {
      final segments = uri.pathSegments;
      final route = segments.length > 1 ? '/${segments.skip(1).join('/')}' : '/home';

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('DeepLinkService: no valid context for navigation to $route');
        return;
      }
      context.go(route);
      debugPrint('DeepLinkService: navigated to $route (from $uri)');
    } catch (e) {
      debugPrint('DeepLinkService: navigation error: $e');
    }
  }
}
