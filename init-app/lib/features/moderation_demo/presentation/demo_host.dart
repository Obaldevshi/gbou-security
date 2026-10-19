import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/app.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/services/connectivity_service.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';

class DemoHost extends StatefulWidget {
  const DemoHost({super.key});
  @override
  State<DemoHost> createState() => _DemoHostState();
}

class _DemoHostState extends State<DemoHost> {
  final _container = GetIt.asNewInstance();
  bool _ready = false, _failed = false, _closing = false;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (getIt<SessionService>().isDemo ||
          getIt<SessionService>().status != SessionStatus.unauthenticated) {
        throw StateError('Demo entry requires logged-out main session');
      }
      await prepareDemoDependencies(_container, getIt<ConnectivityService>());
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      restoreRealContainer(_container);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _exit() async {
    if (_closing) return;
    _closing = true;
    setState(() => _ready = false);
    // Dispose all role pages, subscriptions and the inner router BEFORE restoring the root DI.
    await WidgetsBinding.instance.endOfFrame;
    restoreRealContainer(_container);
    await _container.reset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    restoreRealContainer(_container);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && (_ready || _failed)) _exit();
    },
    child: _ready
        ? MobileTemplateApp(
            demoControls: _DemoControls(container: _container, onExit: _exit),
          )
        : Scaffold(
            body: Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.l10n.demoFailed),
                        TextButton(
                          onPressed: _exit,
                          child: Text(context.l10n.demoExit),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
  );
}

class _DemoControls extends StatefulWidget {
  const _DemoControls({required this.container, required this.onExit});
  final GetIt container;
  final VoidCallback onExit;
  @override
  State<_DemoControls> createState() => _DemoControlsState();
}

class _DemoControlsState extends State<_DemoControls> {
  bool _busy = false;
  int _nextDemoDevice = 1;
  Future<void> _choose(String login) async {
    if (_busy) return;
    if (login == '__pairing_demo') {
      final suffix = (_nextDemoDevice++).toString().padLeft(12, '0');
      final nav = widget.container<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      );
      GoRouter.of(nav.currentContext!).push(
        '${AppRoutes.connectDevices}/11111111-2222-4333-8444-$suffix',
      );
      return;
    }
    setState(() => _busy = true);
    await widget.container<AuthSessionRepository>().login(
      login: login,
      password: MockAuthSessionRepository.password,
    );
    if (!mounted) return;
    final user = widget.container<SessionService>().currentUser;
    final nav = widget.container<GlobalKey<NavigatorState>>(
      instanceName: 'navigatorKey',
    );
    if (mounted && user != null && nav.currentContext != null) {
      GoRouter.of(nav.currentContext!).go(switch (user.role) {
        UserRole.teacher => AppRoutes.teacherRequest,
        UserRole.guard => AppRoutes.guardQueue,
        UserRole.schoolAdmin => AppRoutes.schoolClasses,
        UserRole.superAdmin => AppRoutes.systemSchools,
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.demoNotice,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: context.l10n.demoChooseRole,
            onSelected: _choose,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'teacher.demo',
                child: Text('Учитель'),
              ),
              const PopupMenuItem(value: 'guard.demo', child: Text('Охрана')),
              const PopupMenuItem(
                value: 'school.admin',
                child: Text('Администратор школы'),
              ),
              const PopupMenuItem(
                value: 'superadmin',
                child: Text('Главный администратор'),
              ),
              const PopupMenuItem(
                value: '__pairing_demo',
                child: Text('QR-подключение (демо)'),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Text('Демо-код устройства: 123456'),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Text('Демопароль: DemoPass123!'),
              ),
            ],
            icon: const Icon(Icons.switch_account_outlined),
          ),
          IconButton(
            tooltip: context.l10n.demoExit,
            onPressed: widget.onExit,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
