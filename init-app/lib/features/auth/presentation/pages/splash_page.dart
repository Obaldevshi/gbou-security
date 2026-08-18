import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/extensions/failure_extensions.dart';
import 'package:mobile_template/core/utils/package_info_utils.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionBootstrapCubit>().restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<SessionBootstrapCubit, SessionBootstrapState>(
      builder: (context, state) {
        final failure = state is SessionBootstrapFailure ? state.failure : null;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              context.l10n.appName,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceS),
            Text(
              context.l10n.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceXL),
            if (failure == null)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              Text(
                failure.localizedMessage(context),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceM),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.formMaxWidth,
                ),
                child: GlobalButton(
                  text: context.l10n.retry,
                  onPressed: () =>
                      context.read<SessionBootstrapCubit>().restore(),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceS),
              TextButton.icon(
                onPressed: () => getIt<SessionService>().clearSession(),
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text(
                  'Вернуться ко входу',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            const Spacer(),
            FutureBuilder(
              future: PackageInfoUtils.appVersion(),
              builder: (context, snapshot) => Text(
                'v${snapshot.data ?? ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceM),
          ],
        );
      },
    );

    return Scaffold(
      body: ColoredBox(
        color: AppColors.primary,
        child: SafeArea(
          child: AppLayoutItemBuilder<Widget>(
            narrow: () => Padding(
              padding: AppDimensions.paddingHorizontalL,
              child: content,
            ),
            wide: () => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(width: double.infinity, child: content),
              ),
            ),
          )(context),
        ),
      ),
    );
  }
}
