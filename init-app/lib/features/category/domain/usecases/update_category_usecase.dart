import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/data/models/request/category_request.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class UpdateCategoryUsecase {
  final MainRepository _mainRepository;

  UpdateCategoryUsecase(this._mainRepository);

  Future<Either<Failure, String>> call(int id, CategoryRequest request) async {
    return _mainRepository.updateCategory(id, request);
  }
}
