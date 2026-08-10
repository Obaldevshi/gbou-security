import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/data/models/request/category_request.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class CreateCategoryUseCase {
  final MainRepository _mainRepository;

  CreateCategoryUseCase(this._mainRepository);

  Future<Either<Failure, String>> call(CategoryRequest request) async {
    return await _mainRepository.createCategory(request);
  }
}
