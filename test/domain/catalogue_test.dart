// test/domain/catalogue_test.dart
//
// Browse-taxonomy rules. Pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/domain/entities/catalogue.dart';
import 'package:patelmart/domain/repositories/i_catalogue_repository.dart';
import 'package:patelmart/domain/usecases/catalogue/get_categories.dart';
import 'package:patelmart/domain/usecases/catalogue/get_departments.dart';

Department dept({
  String code = 'D1',
  String name = 'Grocery',
  int sequence = 0,
}) =>
    Department(
      id: 'id-$code',
      code: code,
      name: name,
      imageUrl: '',
      sequence: sequence,
    );

final class _FakeCatalogueRepo implements ICatalogueRepository {
  List<Department> departmentList = const [];
  String? lastStoreCode;

  @override
  Future<Result<List<Department>>> departments(String storeCode) async {
    lastStoreCode = storeCode;
    return Ok(departmentList);
  }

  @override
  Future<Result<List<Category>>> categories({
    required String departmentCode,
    required String storeCode,
  }) async =>
      const Ok([]);

  @override
  Future<Result<List<Subcategory>>> subcategories(String categoryCode) async =>
      const Ok([]);

  @override
  Future<Result<void>> clearCache() async => const Ok(null);
}

void main() {
  group('isDisplayable', () {
    test('needs both a code and a name', () {
      expect(dept().isDisplayable, isTrue);
      expect(dept(code: '').isDisplayable, isFalse);
      expect(dept(name: '').isDisplayable, isFalse);
      expect(dept(name: '   ').isDisplayable, isFalse);
    });
  });

  group('displayable extension', () {
    test('sorts by sequence', () {
      final list = [
        dept(code: 'C', sequence: 3),
        dept(code: 'A', sequence: 1),
        dept(code: 'B', sequence: 2),
      ].displayable;

      expect(list.map((d) => d.code), ['A', 'B', 'C']);
    });

    test('drops undisplayable rows', () {
      // Unnamed placeholder rows used to reach the UI because each screen
      // filtered by hand, or forgot to.
      final list = [
        dept(code: 'A'),
        dept(code: '', name: 'orphan'),
        dept(code: 'B', name: ''),
      ].displayable;

      expect(list.map((d) => d.code), ['A']);
    });

    test('returns an unmodifiable list', () {
      final list = [dept()].displayable;

      expect(() => list.add(dept(code: 'X')), throwsUnsupportedError);
    });

    test('handles an empty input', () {
      expect(<Department>[].displayable, isEmpty);
    });
  });

  group('identity', () {
    test('code identifies a node', () {
      expect(dept(code: 'D1', name: 'A'), dept(code: 'D1', name: 'B'));
      expect(dept(code: 'D1'), isNot(dept(code: 'D2')));
    });

    test('levels with the same code are still different types', () {
      // A Department and a Subcategory sharing a code are not interchangeable.
      const department =
          Department(id: '', code: 'X', name: 'n', imageUrl: '', sequence: 0);
      const subcategory = Subcategory(id: '', code: 'X', name: 'n', categoryCode: 'c');

      expect(department == subcategory, isFalse);
    });
  });

  group('GetDepartments', () {
    late _FakeCatalogueRepo repo;
    setUp(() => repo = _FakeCatalogueRepo());

    test('rejects an empty store code without calling the repository', () async {
      final result =
          await GetDepartments(repo)(const GetDepartmentsParams(storeCode: ''));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.lastStoreCode, isNull);
    });

    test('returns departments filtered and ordered', () async {
      repo.departmentList = [
        dept(code: 'C', sequence: 2),
        dept(code: '', name: 'junk'),
        dept(code: 'A', sequence: 1),
      ];

      final result = await GetDepartments(repo)(
        const GetDepartmentsParams(storeCode: 'KLK'),
      );

      expect(result.valueOrNull!.map((d) => d.code), ['A', 'C']);
    });
  });

  group('GetCategories', () {
    test('rejects a missing department or store', () async {
      final repo = _FakeCatalogueRepo();

      expect(
        (await GetCategories(repo)(
          const GetCategoriesParams(departmentCode: '', storeCode: 'KLK'),
        ))
            .failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await GetCategories(repo)(
          const GetCategoriesParams(departmentCode: 'D1', storeCode: ''),
        ))
            .failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });
}
