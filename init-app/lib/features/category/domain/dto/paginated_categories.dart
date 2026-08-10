import 'package:mobile_template/features/category/domain/dto/category_dto.dart';

class PaginatedCategories {
  final List<CategoryDto> items;
  final int total;
  final int page;
  final int perPage;

  const PaginatedCategories({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  bool get hasMore => page * perPage < total;
}
