import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/privacy/domain/privacy_policy.dart';

class BundledPrivacyRepository implements PrivacyPolicyRepository {
  BundledPrivacyRepository([AssetBundle? bundle])
    : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  @override
  Future<Either<Failure, PrivacyPolicy>> load() async {
    try {
      final json =
          jsonDecode(await _bundle.loadString('assets/privacy/policy.json'))
              as Map<String, dynamic>;
      return Right(
        PrivacyPolicy(
          title: json['title'] as String,
          version: json['version'] as String,
          approved: json['approved'] == true,
          operatorName: json['operator_name'] as String,
          contactEmail: json['contact_email'] as String,
          retentionPolicy: json['retention_policy'] as String,
          publicUrl: json['public_url'] as String,
          sections: (json['sections'] as List)
              .map(
                (item) => PrivacySection(
                  item['title'] as String,
                  item['text'] as String,
                ),
              )
              .toList(growable: false),
        ),
      );
    } catch (_) {
      return const Left(
        ServerFailure(
          message: 'Не удалось открыть политику конфиденциальности',
        ),
      );
    }
  }
}
