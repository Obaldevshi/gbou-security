import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class DeleteCategoryUsecase {
  final MainRepository _mainRepository;

  DeleteCategoryUsecase(this._mainRepository);

  Future<Either<Failure, void>> call(int id) async {
    return _mainRepository.deleteCategory(id);
  }
}
