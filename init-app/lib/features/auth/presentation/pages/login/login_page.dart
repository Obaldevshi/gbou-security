import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/utils/validation_utils.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/widgets/auth_scroll_scaffold.dart';
import 'package:mobile_template/features/auth/presentation/widgets/login_hero_section.dart';
import 'package:mobile_template/presentation/widgets/common/error_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(
        login: _loginController.text.trim().toLowerCase(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginFailure) {
          ErrorDialog.show(context, state.failure);
        } else if (state is LoginSuccess) {
          _passwordController.clear();
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        return AuthScrollScaffold(
          hero: LoginHeroSection(
            title: context.l10n.welcomeBack,
            subtitle: context.l10n.loginSubtitle,
          ),
          form: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusL,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_person_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: AppDimensions.iconL,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
                  Text(
                    context.l10n.loginPortalTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceS),
                  Text(
                    context.l10n.loginPortalDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceXL),
                  GlobalTextFormField(
                    controller: _loginController,
                    labelText: context.l10n.loginField,
                    hintText: context.l10n.loginHint,
                    enabled: !isLoading,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) => ValidationUtils.validateRequired(
                      value?.trim(),
                      context.l10n.loginField,
                      context,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  GlobalTextFormField(
                    controller: _passwordController,
                    labelText: context.l10n.password,
                    hintText: context.l10n.passwordHint,
                    enabled: !isLoading,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!isLoading) _handleLogin();
                    },
                    suffixIcon: IconButton(
                      tooltip: _isPasswordVisible
                          ? context.l10n.hidePassword
                          : context.l10n.showPassword,
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: isLoading
                          ? null
                          : () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                    ),
                    validator: (value) => ValidationUtils.validateRequired(
                      value,
                      context.l10n.password,
                      context,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceXL),
                  GlobalButton(
                    text: context.l10n.signIn,
                    onPressed: _handleLogin,
                    isLoading: isLoading,
                    isEnabled: !isLoading,
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
                  Text(
                    context.l10n.loginSupportHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
