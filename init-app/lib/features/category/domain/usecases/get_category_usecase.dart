import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:mobile_template/features/category/domain/dto/category_dto.dart';
import 'package:mobile_template/features/category/domain/dto/paginated_categories.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetCategoryUsecase {
  final MainRepository _mainRepository;

  GetCategoryUsecase(this._mainRepository);

  Future<Either<Failure, PaginatedCategories>> call({
    int page = 1,
    int perPage = 20,
    String sortBy = 'id',
    String sortOrder = 'desc',
  }) async {
    final result = await _mainRepository.getCategories(
      page: page,
      perPage: perPage,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    return result.map(
      (response) => PaginatedCategories(
        items: CategoryDto.fromCategoryResponseList(response.data),
        total: response.total,
        page: response.page,
        perPage: response.perPage,
      ),
    );
  }
}
