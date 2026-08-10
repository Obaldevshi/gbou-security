import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/data/models/request/category_request.dart';
import 'package:mobile_template/data/models/response/base_pagination_response.dart';
import 'package:mobile_template/data/models/response/category_response.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class MainRepository {
  Future<Either<Failure, BasePaginationResponse<CategoryResponse>>>
  getCategories({
    int page = 1,
    int perPage = 20,
    String sortBy = 'id',
    String sortOrder = 'desc',
  });

  Future<Either<Failure, String>> createCategory(CategoryRequest request);

  Future<Either<Failure, String>> updateCategory(
    int id,
    CategoryRequest request,
  );

  Future<Either<Failure, void>> deleteCategory(int id);
}
