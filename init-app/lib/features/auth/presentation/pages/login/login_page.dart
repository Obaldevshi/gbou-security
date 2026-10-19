import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/utils/validation_utils.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/widgets/auth_scroll_scaffold.dart';
import 'package:mobile_template/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:mobile_template/features/auth/domain/repositories/routing_identifier.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';
import 'package:mobile_template/presentation/widgets/common/error_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({this.systemLogin = false, super.key});
  final bool systemLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _preparing = false;
  String? _connectionError;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_preparing || _formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _preparing = true;
      _connectionError = null;
    });
    try {
      if (!getIt<SessionService>().isDemo) {
        final connection = getIt<SchoolConnectionService>();
        if (widget.systemLogin) {
          await connection.select(
            SchoolConnection.parse(connection.defaultBaseUrl),
          );
        } else if (connection.supportsDiscovery &&
            !connection.automaticDiscovery) {
          await connection.enableAutomaticDiscovery();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _connectionError = context.l10n.errorServer);
      return;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(
        login: _loginController.text.trim().toLowerCase(),
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _selectBuilding(BuildingSelectionRequired failure) async {
    final login = _loginController.text.trim().toLowerCase();
    final selected = await showDialog<SchoolDestination>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.l10n.chooseLoginBuilding),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.chooseLoginBuildingHint),
                const SizedBox(height: 12),
                for (final choice in failure.choices)
                  ListTile(
                    leading: const Icon(Icons.domain_outlined),
                    title: Text(
                      choice.buildingName ??
                          '${context.l10n.qrSetupBuilding} ${choice.buildingId}',
                    ),
                    subtitle: Text(choice.origin),
                    onTap: () => Navigator.pop(dialog, choice),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.l10n.schoolDevicesCancel),
          ),
        ],
      ),
    );
    if (!mounted ||
        selected == null ||
        login != _loginController.text.trim().toLowerCase()) {
      return;
    }
    getIt<SchoolConnectionService>().chooseBuildingOrigin(
      schoolLoginDigest(login),
      selected.origin,
    );
    await _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginFailure) {
          if (state.failure case final BuildingSelectionRequired failure) {
            _selectBuilding(failure);
          } else if (widget.systemLogin &&
              state.failure.errorCode == 'local_access_required') {
            // Never retry a school password against central authentication.
            // A deliberate return to the school form starts a new attempt.
            _passwordController.clear();
            showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                scrollable: true,
                title: Text(context.l10n.systemLoginAction),
                content: Text(context.l10n.systemLoginHint),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialog);
                      context.go(AppRoutes.login);
                    },
                    child: Text(context.l10n.schoolLoginAction),
                  ),
                ],
              ),
            );
          } else {
            ErrorDialog.show(context, state.failure);
          }
        } else if (state is LoginSuccess) {
          _passwordController.clear();
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading || _preparing;
        return AuthScrollScaffold(
          form: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.systemLogin) ...[
                    Text(
                      context.l10n.systemLoginAction,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.spaceS),
                    Text(
                      context.l10n.systemLoginHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
                  if (_connectionError != null)
                    Text(
                      _connectionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  GlobalButton(
                    text: widget.systemLogin
                        ? context.l10n.systemLoginSubmit
                        : context.l10n.signIn,
                    onPressed: _handleLogin,
                    isLoading: isLoading,
                    isEnabled: !isLoading,
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  AuthLegalFooter(systemLogin: widget.systemLogin),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
