import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/role_module_loader.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

class DeferredRolePage extends StatefulWidget {
  const DeferredRolePage({
    required this.role,
    required this.destination,
    this.navigationShell,
    super.key,
  });

  final UserRole role;
  final RoleDestination destination;
  final StatefulNavigationShell? navigationShell;

  @override
  State<DeferredRolePage> createState() => _DeferredRolePageState();
}

class _DeferredRolePageState extends State<DeferredRolePage> {
  late Future<void> _loading = _loadRoleModule();

  Future<void> _loadRoleModule() async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await loadRoleModule(widget.role);
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 450 << attempt));
        }
      }
    }
    throw lastError!;
  }

  @override
  void didUpdateWidget(covariant DeferredRolePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _loading = _loadRoleModule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return buildRoleDestination(
            widget.role,
            widget.destination,
            navigationShell: widget.navigationShell,
          );
        }
        return _RoleLoadingView(
          role: widget.role,
          error: snapshot.error,
          onRetry: () => setState(() {
            _loading = _loadRoleModule();
          }),
        );
      },
    );
  }
}

class _RoleLoadingView extends StatelessWidget {
  const _RoleLoadingView({
    required this.role,
    required this.error,
    required this.onRetry,
  });

  final UserRole role;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final roleName = switch (role) {
      UserRole.teacher => 'учителя',
      UserRole.guard => 'охранника',
      UserRole.schoolAdmin => 'администратора школы',
      UserRole.superAdmin => 'главного администратора',
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Загружаем кабинет $roleName…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Это выполняется только при первом открытии.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ] else ...[
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить кабинет',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
