import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/data/models/request/category_request.dart';
import 'package:mobile_template/features/category/domain/dto/category_dto.dart';
import 'package:mobile_template/features/category/domain/usecases/create_category_usecase.dart';
import 'package:mobile_template/features/category/domain/usecases/delete_category_usecase.dart';
import 'package:mobile_template/features/category/domain/usecases/get_category_usecase.dart';
import 'package:mobile_template/features/category/domain/usecases/update_category_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'category_event.dart';
part 'category_state.dart';

@injectable
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final GetCategoryUsecase _getCategoryUsecase;
  final CreateCategoryUseCase _createCategoryUseCase;
  final UpdateCategoryUsecase _updateCategoryUsecase;
  final DeleteCategoryUsecase _deleteCategoryUsecase;

  CategoryBloc(
    this._getCategoryUsecase,
    this._createCategoryUseCase,
    this._updateCategoryUsecase,
    this._deleteCategoryUsecase,
  ) : super(CategoryInitial()) {
    on<GetCategoryEvent>(_onGetCategory);
    on<CreateCategoryEvent>(_onCreateCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
  }

  Future<void> _onGetCategory(
    GetCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    if (!event.append) {
      emit(CategoryLoading());
    }

    final currentCategories = state is CategoryLoaded && event.append
        ? (state as CategoryLoaded).categories
        : <CategoryDto>[];

    final result = await _getCategoryUsecase.call(page: event.page);
    result.fold((failure) => emit(CategoryError(failure: failure)), (
      paginated,
    ) {
      final categories = event.append
          ? [...currentCategories, ...paginated.items]
          : paginated.items;
      emit(
        CategoryLoaded(
          categories: categories,
          total: paginated.total,
          page: paginated.page,
          hasMore: paginated.hasMore,
        ),
      );
    });
  }

  Future<void> _onCreateCategory(
    CreateCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoading());
    final request = CategoryRequest(name: event.name);
    final result = await _createCategoryUseCase.call(request);
    result.fold(
      (failure) => emit(CategoryError(failure: failure)),
      (message) => emit(CreateCategorySuccess(message: message)),
    );
  }

  Future<void> _onUpdateCategory(
    UpdateCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(UpdateCategoryLoading());
    final result = await _updateCategoryUsecase.call(
      event.id,
      CategoryRequest(name: event.name),
    );
    result.fold(
      (failure) => emit(UpdateCategoryError(failure: failure)),
      (message) => emit(UpdateCategorySuccess(message: message)),
    );
  }

  Future<void> _onDeleteCategory(
    DeleteCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(DeleteCategoryLoading());
    final result = await _deleteCategoryUsecase.call(event.id);
    result.fold(
      (failure) => emit(DeleteCategoryError(failure: failure)),
      (_) => emit(DeleteCategorySuccess()),
    );
  }
}
