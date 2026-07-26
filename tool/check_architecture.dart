// tool/check_architecture.dart
//
// Enforces the dependency rule from docs/ARCHITECTURE.md.
//
//   presentation ──▶ domain ◀── data
//                      ▲
//                    core
//
//           di/  ──▶ may see every layer
//
// Dart's analyzer cannot express import restrictions without adding
// custom_lint and import_lint as dependencies, so this runs as a script:
//
//   dart run tool/check_architecture.dart
//
// Exit code 1 on any violation, so CI fails the build rather than leaving the
// rule to be caught in review — which is how the original 26 inverted imports
// accumulated in the first place.

import 'dart:io';

/// A forbidden edge: files under [from] must not import anything under [to].
class Rule {
  final String from;
  final String to;
  final String why;

  const Rule(this.from, this.to, this.why);
}

const rules = <Rule>[
  Rule('lib/domain', 'lib/data',
      'domain must not know how data is fetched or stored'),
  Rule('lib/domain', 'lib/presentation',
      'domain must not know about the UI'),
  Rule('lib/domain', 'lib/di', 'domain must not know how it is wired'),
  Rule('lib/data', 'lib/presentation',
      'data must not depend on UI state; invert the dependency'),
  Rule('lib/core', 'lib/presentation',
      'core is framework plumbing with no feature knowledge'),
  Rule('lib/core', 'lib/data', 'core must not know about repositories'),
  Rule('lib/core', 'lib/domain', 'core sits below domain'),
  Rule('lib/presentation', 'lib/data/repositories',
      'presentation talks to use cases, not repositories'),
  Rule('lib/presentation', 'lib/data/datasources',
      'presentation must never reach a datasource'),
];

/// Packages the domain layer may not import — it must stay pure Dart.
const forbiddenDomainPackages = <String>[
  'package:flutter/',
  'package:http/',
  'package:shared_preferences/',
  'package:geolocator/',
  'package:firebase',
  'package:razorpay',
  'dart:io',
];

void main() {
  final violations = <String>[];

  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final path = file.path.replaceAll(r'\', '/');
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('import ') && !line.startsWith('export ')) continue;
      // Ignore commented-out directives.
      if (line.startsWith('//')) continue;

      final match = RegExp("['\"]([^'\"]+)['\"]").firstMatch(line);
      if (match == null) continue;
      final target = match.group(1)!;

      // Layer-to-layer rules, for both package: and relative imports.
      for (final rule in rules) {
        if (!path.startsWith('${rule.from}/')) continue;
        final segment = rule.to.replaceFirst('lib/', '');
        final hits = target.startsWith('package:patelmart/$segment/') ||
            (target.startsWith('.') && _resolve(path, target).startsWith(rule.to));
        if (hits) {
          violations.add(
              '${path}:${i + 1}\n    imports ${rule.to} — ${rule.why}\n    $line');
        }
      }

      // Domain purity.
      if (path.startsWith('lib/domain/')) {
        for (final pkg in forbiddenDomainPackages) {
          if (target.startsWith(pkg)) {
            violations.add(
                '${path}:${i + 1}\n    imports $target — domain must be pure Dart\n    $line');
          }
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Architecture OK — no layer violations.');
    exit(0);
  }

  stderr.writeln('Architecture violations (${violations.length}):\n');
  for (final v in violations) {
    stderr.writeln('  $v\n');
  }
  stderr.writeln('See docs/ARCHITECTURE.md for the dependency rule.');
  exit(1);
}

/// Resolves a relative import against the importing file's directory.
String _resolve(String fromFile, String relative) {
  final base = fromFile.split('/')..removeLast();
  for (final part in relative.split('/')) {
    if (part == '..') {
      if (base.isNotEmpty) base.removeLast();
    } else if (part != '.') {
      base.add(part);
    }
  }
  return base.join('/');
}
