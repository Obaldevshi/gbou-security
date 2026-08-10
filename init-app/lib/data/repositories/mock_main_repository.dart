import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/data/fixtures/mock_data_store.dart';
import 'package:mobile_template/data/models/request/category_request.dart';
import 'package:mobile_template/data/models/response/base_pagination_response.dart';
import 'package:mobile_template/data/models/response/category_response.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:fpdart/fpdart.dart';

class MockMainRepository implements MainRepository {
  final _store = MockDataStore.instance;

  static const _networkDelay = Duration(milliseconds: 300);

  Future<void> _simulateNetwork() => Future<void>.delayed(_networkDelay);

  @override
  Future<Either<Failure, BasePaginationResponse<CategoryResponse>>>
  getCategories({
    int page = 1,
    int perPage = 20,
    String sortBy = 'id',
    String sortOrder = 'desc',
  }) async {
    await _simulateNetwork();

    final sorted = List<CategoryResponse>.from(_store.categories);
    sorted.sort((a, b) {
      final comparison = switch (sortBy) {
        'name' => a.name.compareTo(b.name),
        _ => a.id.compareTo(b.id),
      };
      return sortOrder == 'asc' ? comparison : -comparison;
    });

    final total = sorted.length;
    final start = (page - 1) * perPage;
    final pageItems = start >= total
        ? <CategoryResponse>[]
        : sorted.skip(start).take(perPage).toList();

    return Right(
      BasePaginationResponse(
        message: 'Categories retrieved successfully',
        total: total,
        page: page,
        perPage: perPage,
        data: pageItems,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> createCategory(
    CategoryRequest request,
  ) async {
    await _simulateNetwork();

    final exists = _store.categories.any(
      (category) => category.name.toLowerCase() == request.name.toLowerCase(),
    );
    if (exists) {
      return const Left(
        ValidationFailure(
          message: 'Category with this name already exists',
          statusCode: 400,
        ),
      );
    }

    _store.categories.add(
      CategoryResponse(id: _store.nextCategoryId(), name: request.name),
    );

    return const Right('Category created successfully');
  }

  @override
  Future<Either<Failure, String>> updateCategory(
    int id,
    CategoryRequest request,
  ) async {
    await _simulateNetwork();

    final index = _store.categories.indexWhere((category) => category.id == id);
    if (index == -1) {
      return const Left(
        ServerFailure(message: 'Category not found', statusCode: 404),
      );
    }

    final duplicate = _store.categories.any(
      (category) =>
          category.id != id &&
          category.name.toLowerCase() == request.name.toLowerCase(),
    );
    if (duplicate) {
      return const Left(
        ValidationFailure(
          message: 'Category with this name already exists',
          statusCode: 400,
        ),
      );
    }

    _store.categories[index] = CategoryResponse(id: id, name: request.name);
    return const Right('Category updated successfully');
  }

  @override
  Future<Either<Failure, void>> deleteCategory(int id) async {
    await _simulateNetwork();

    final index = _store.categories.indexWhere((category) => category.id == id);
    if (index == -1) {
      return const Left(
        ServerFailure(message: 'Category not found', statusCode: 404),
      );
    }

    _store.categories.removeAt(index);
    return const Right(null);
  }
}
