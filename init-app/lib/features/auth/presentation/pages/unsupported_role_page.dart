import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/usecases/logout_usecase.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';

class UnsupportedRolePage extends StatelessWidget {
  const UnsupportedRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = getIt<SessionService>().currentUser;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppDimensions.paddingAllL,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.formMaxWidth,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: AppDimensions.paddingAllL,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        size: AppDimensions.iconXL,
                      ),
                      const SizedBox(height: AppDimensions.spaceM),
                      Text(
                        user?.fullName ?? context.l10n.user,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceS),
                      Text(
                        context.l10n.unsupportedRole,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceL),
                      GlobalButton(
                        text: context.l10n.logout,
                        onPressed: () => getIt<LogoutUsecase>()(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
