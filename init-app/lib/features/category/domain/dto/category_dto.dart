import 'package:mobile_template/data/models/response/category_response.dart';

class CategoryDto {
  final int id;
  final String name;

  CategoryDto({required this.id, required this.name});

  factory CategoryDto.fromCategoryResponse(CategoryResponse response) {
    return CategoryDto(id: response.id, name: response.name);
  }

  static List<CategoryDto> fromCategoryResponseList(
    List<CategoryResponse> responses,
  ) {
    return responses.map(CategoryDto.fromCategoryResponse).toList();
  }
}
