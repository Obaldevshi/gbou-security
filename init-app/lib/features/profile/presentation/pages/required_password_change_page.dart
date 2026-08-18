import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/presentation/widgets/password_text_field.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/presentation/widgets/common/error_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';

class RequiredPasswordChangePage extends StatefulWidget {
  const RequiredPasswordChangePage({super.key});

  @override
  State<RequiredPasswordChangePage> createState() =>
      _RequiredPasswordChangePageState();
}

class _RequiredPasswordChangePageState
    extends State<RequiredPasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppDimensions.paddingAllL,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: BlocConsumer<ProfileBloc, ProfileState>(
                listener: (context, state) async {
                  if (state is ChangePasswordFailure) {
                    ErrorDialog.show(context, state.failure);
                  } else if (state is ChangePasswordSuccess) {
                    await getIt<SessionService>().clearSession();
                  }
                },
                builder: (context, state) {
                  final loading = state is ChangePasswordLoading;
                  return GlassSurfaceCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.password_rounded,
                            size: AppDimensions.iconXL,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: AppDimensions.spaceM),
                          Text(
                            context.l10n.requiredPasswordTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppDimensions.spaceS),
                          Text(
                            context.l10n.requiredPasswordDescription,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spaceXL),
                          PasswordTextField(
                            controller: _current,
                            labelText: context.l10n.currentPassword,
                            hintText: context.l10n.enterCurrentPassword,
                            validator: _required,
                          ),
                          const SizedBox(height: AppDimensions.spaceM),
                          PasswordTextField(
                            controller: _next,
                            labelText: context.l10n.newPassword,
                            hintText: context.l10n.enterNewPassword,
                            validator: _strongPassword,
                          ),
                          const SizedBox(height: AppDimensions.spaceM),
                          PasswordTextField(
                            controller: _repeat,
                            labelText: context.l10n.confirmNewPassword,
                            hintText: context.l10n.confirmYourNewPassword,
                            validator: (value) => value != _next.text
                                ? context.l10n.passwordsDontMatch
                                : _required(value),
                          ),
                          const SizedBox(height: AppDimensions.spaceL),
                          GlobalButton(
                            text: context.l10n.changePasswordButton,
                            isLoading: loading,
                            isEnabled: !loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.isEmpty ? context.l10n.passwordRequired : null;

  String? _strongPassword(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final password = value!;
    if (password.length < 8 ||
        !RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(password)) {
      return context.l10n.passwordStrengthHint;
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<ProfileBloc>().add(
      ChangePasswordEvent(
        currentPassword: _current.text,
        newPassword: _next.text,
      ),
    );
  }
}
