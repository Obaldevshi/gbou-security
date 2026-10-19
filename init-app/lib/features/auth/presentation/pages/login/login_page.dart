import 'package:flutter/material.dart';
import 'package:mobile_template/core/utils/app_navigator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/features/moderation_demo/presentation/demo_host.dart';
import 'package:mobile_template/core/utils/app_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/utils/validation_utils.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/widgets/auth_scroll_scaffold.dart';
import 'package:mobile_template/features/auth/presentation/widgets/school_connection_dialog.dart';
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
          form: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  GlobalTextFormField(
                    controller: _loginController,
                    labelText: context.l10n.loginField,
                    hintText: context.l10n.loginHint,
                    enabled: !isLoading,
                    autofocus: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) => ValidationUtils.validateRequired(
                      value?.trim(),
                      context.l10n.loginField,
                      context,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
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
                  const SizedBox(height: AppDimensions.spaceL),
                  GlobalButton(
                    text: context.l10n.signIn,
                    onPressed: _handleLogin,
                    isLoading: isLoading,
                    isEnabled: !isLoading,
                  ),
                  if (!getIt<SessionService>().isDemo &&
                      (!kIsWeb ||
                          getIt<SchoolConnectionService>()
                              .supportsDiscovery)) ...[
                    const SizedBox(height: AppDimensions.spaceS),
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              _passwordController.clear();
                              await showDialog<void>(
                                context: appNavigator(context).context,
                                useRootNavigator: false,
                                builder: (_) => const SchoolConnectionDialog(),
                              );
                              if (mounted) setState(() {});
                            },
                      icon: const Icon(Icons.router_outlined),
                      label: Text(
                        getIt<SchoolConnectionService>().automaticDiscovery
                            ? 'Школа определяется по логину · настройки'
                            : 'Подключение к школе · настройки',
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: () => context.push(AppRoutes.privacy),
                    child: Text(context.l10n.privacyTitle),
                  ),
                  if (!getIt<SessionService>().isDemo)
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              _passwordController.clear();
                              FocusManager.instance.primaryFocus?.unfocus();
                              context.push(AppRoutes.scanDevice);
                            },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(context.l10n.qrScannerTitle),
                    ),
                  if (!getIt<SessionService>().isDemo)
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              _passwordController.clear();
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => const DemoHost(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(context.l10n.demoTitle),
                    ),
                  TextButton(
                    onPressed: () => showAppLicenses(context),
                    child: const Text('Лицензии компонентов'),
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
