import 'package:mobile_template/data/models/response/category_response.dart';
import 'package:mobile_template/features/profile/domain/dto/profile_dto.dart';

class MockDataStore {
  MockDataStore._();

  static final MockDataStore instance = MockDataStore._();

  static const mockPassword = 'password123';
  static const mockEmail = 'demo@template.local';

  ProfileDto profile = ProfileDto(
    id: 1,
    login: mockEmail,
    fullName: 'Демо Пользователь',
    role: 'teacher',
    isActive: true,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
  );

  String password = mockPassword;

  final List<CategoryResponse> categories = [
    CategoryResponse(id: 1, name: 'Work'),
    CategoryResponse(id: 2, name: 'Personal'),
    CategoryResponse(id: 3, name: 'Travel'),
    CategoryResponse(id: 4, name: 'Health'),
    CategoryResponse(id: 5, name: 'Finance'),
    CategoryResponse(id: 6, name: 'Education'),
    CategoryResponse(id: 7, name: 'Shopping'),
    CategoryResponse(id: 8, name: 'Entertainment'),
    CategoryResponse(id: 9, name: 'Family'),
    CategoryResponse(id: 10, name: 'Other'),
  ];

  int _nextCategoryId = 11;

  int nextCategoryId() => _nextCategoryId++;

  void reset() {
    profile = ProfileDto(
      id: 1,
      login: mockEmail,
      fullName: 'Демо Пользователь',
      role: 'teacher',
      isActive: true,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    );
    password = mockPassword;
    categories
      ..clear()
      ..addAll([
        CategoryResponse(id: 1, name: 'Work'),
        CategoryResponse(id: 2, name: 'Personal'),
        CategoryResponse(id: 3, name: 'Travel'),
        CategoryResponse(id: 4, name: 'Health'),
        CategoryResponse(id: 5, name: 'Finance'),
        CategoryResponse(id: 6, name: 'Education'),
        CategoryResponse(id: 7, name: 'Shopping'),
        CategoryResponse(id: 8, name: 'Entertainment'),
        CategoryResponse(id: 9, name: 'Family'),
        CategoryResponse(id: 10, name: 'Other'),
      ]);
    _nextCategoryId = 11;
  }
}
