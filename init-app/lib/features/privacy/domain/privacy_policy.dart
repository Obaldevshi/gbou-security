import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class PrivacySection {
  const PrivacySection(this.title, this.text);
  final String title;
  final String text;
}

class PrivacyPolicy {
  const PrivacyPolicy({
    required this.title,
    required this.version,
    required this.approved,
    required this.operatorName,
    required this.contactEmail,
    required this.retentionPolicy,
    required this.publicUrl,
    required this.sections,
  });
  final String title,
      version,
      operatorName,
      contactEmail,
      retentionPolicy,
      publicUrl;
  final bool approved;
  final List<PrivacySection> sections;
  bool get ready =>
      approved &&
      operatorName.trim().isNotEmpty &&
      contactEmail.contains('@') &&
      retentionPolicy.trim().isNotEmpty;
}

abstract interface class PrivacyPolicyRepository {
  Future<Either<Failure, PrivacyPolicy>> load();
}
