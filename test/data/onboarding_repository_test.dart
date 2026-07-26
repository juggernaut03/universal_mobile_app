// test/data/onboarding_repository_test.dart
//
// Onboarding is the first thing a user ever sees, so the repository's job is
// to never produce a blank screen: API, then cache, then the bundled set.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/models/onboarding_slide_model.dart';
import 'package:patelmart/data/repositories/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _slide(String id, {String title = 'Slide', String image = 'https://cdn/x.png'}) => {
      'id': id,
      'title': '$title $id',
      'description': 'Description $id',
      'image_url': image,
    };

String _body(List<Map<String, dynamic>> slides) =>
    jsonEncode({'success': true, 'count': slides.length, 'data': slides});

OnboardingRepository _build(MockClient client) => OnboardingRepository(
      apiClient: ApiClient(client: client, logger: Logger()),
      logger: Logger(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns the configured slides in the order the API sent them', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([_slide('a'), _slide('b')]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final slides = await repository.getSlides();

    expect(slides.map((s) => s.title), ['Slide a', 'Slide b']);
    expect(slides.every((s) => s.isAsset), isFalse);
  });

  test('a tenant with no slides configured gets the bundled set', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final slides = await repository.getSlides();

    expect(slides, OnboardingSlideModel.bundledDefaults);
    expect(slides.every((s) => s.isAsset), isTrue);
  });

  test('slides missing a title or an image are dropped, not rendered blank', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([
            _slide('a'),
            {'id': 'b', 'title': '', 'image_url': 'https://cdn/b.png'},
            {'id': 'c', 'title': 'No image', 'image_url': ''},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final slides = await repository.getSlides();

    expect(slides.map((s) => s.id), ['a']);
  });

  test('a failed request falls back to the last good response', () async {
    var failing = false;
    final client = MockClient((_) async {
      if (failing) return http.Response('nope', 500);
      return http.Response(
        _body([_slide('a')]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repository = _build(client);
    await repository.getSlides(); // primes the cache

    failing = true;
    final slides = await repository.getSlides();

    expect(slides.map((s) => s.id), ['a']);
    expect(slides.first.isAsset, isFalse); // the cached remote slide, not bundled
  });

  test('a failure with no cache still yields the bundled set', () async {
    final repository = _build(MockClient((_) async => http.Response('nope', 500)));

    final slides = await repository.getSlides();

    expect(slides, OnboardingSlideModel.bundledDefaults);
  });

  test('a malformed body is treated as a failure, not a crash', () async {
    final repository = _build(MockClient((_) async => http.Response(
          '{"success": true, "data": "not-a-list"}',
          200,
          headers: {'content-type': 'application/json'},
        )));

    final slides = await repository.getSlides();

    expect(slides, OnboardingSlideModel.bundledDefaults);
  });
}
