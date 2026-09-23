import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/trusted_device.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({super.key});

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_pin.length != 4 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await getIt<AuthSessionRepository>().unlockWithPin(_pin);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _pin = '';
        _error = _message(failure);
      }),
      (_) => setState(() => _busy = false),
    );
  }

  @override
  Widget build(BuildContext context) => _PinScaffold(
    title: 'Быстрый вход',
    subtitle: 'Введите четырёхзначный PIN этого устройства',
    pin: _pin,
    error: _error,
    busy: _busy,
    onDigit: (digit) {
      if (_pin.length >= 4 || _busy) return;
      setState(() {
        _pin += digit;
        _error = null;
      });
    },
    onBackspace: () {
      if (_pin.isNotEmpty && !_busy) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    },
    onSubmit: _submit,
    footer: TextButton(
      onPressed: _busy
          ? null
          : () async {
              await getIt<AuthSessionRepository>().disablePin();
            },
      child: const Text('Войти по логину и паролю'),
    ),
  );
}

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String _pin = '';
  String? _firstPin;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_pin.length != 4 || _busy) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _error = null;
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _firstPin = null;
        _error = 'PIN-коды не совпали. Попробуйте ещё раз.';
      });
      return;
    }
    setState(() => _busy = true);
    final result = await getIt<AuthSessionRepository>().enablePin(_pin);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _pin = '';
        _firstPin = null;
        _error = _message(failure);
      }),
      (_) => setState(() => _busy = false),
    );
  }

  @override
  Widget build(BuildContext context) => _PinScaffold(
    title: _firstPin == null ? 'Создайте PIN' : 'Повторите PIN',
    subtitle: _firstPin == null
        ? 'После первого входа приложение сможет открываться быстрее'
        : 'Введите те же четыре цифры ещё раз',
    pin: _pin,
    error: _error,
    busy: _busy,
    onDigit: (digit) {
      if (_pin.length >= 4 || _busy) return;
      setState(() {
        _pin += digit;
        _error = null;
      });
    },
    onBackspace: () {
      if (_pin.isNotEmpty && !_busy) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    },
    onSubmit: _submit,
    footer: TextButton(
      onPressed: _busy
          ? null
          : () async {
              await getIt<SessionService>().dismissPinOffer();
            },
      child: const Text('Не сейчас'),
    ),
  );
}

class _PinScaffold extends StatelessWidget {
  const _PinScaffold({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.busy,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.footer,
    this.error,
  });

  final String title;
  final String subtitle;
  final String pin;
  final String? error;
  final bool busy;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppDimensions.spaceM),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceS),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceL),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < pin.length
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: error == null
                            ? null
                            : Center(
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                      ),
                      _PinPad(
                        enabled: !busy,
                        onDigit: onDigit,
                        onBackspace: onBackspace,
                      ),
                      const SizedBox(height: AppDimensions.spaceM),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: pin.length == 4 && !busy ? onSubmit : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Продолжить'),
                          ),
                        ),
                      ),
                      footer,
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

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = <String>['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var column = 0; column < 3; column++)
                _PinKey(
                  label: keys[row * 3 + column],
                  enabled: enabled,
                  onPressed: () => onDigit(keys[row * 3 + column]),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 68, height: 56),
            _PinKey(
              label: '0',
              enabled: enabled,
              onPressed: () => onDigit('0'),
            ),
            SizedBox(
              width: 68,
              height: 56,
              child: IconButton(
                onPressed: enabled ? onBackspace : null,
                icon: const Icon(Icons.backspace_outlined),
                tooltip: 'Удалить цифру',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 56,
    child: TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}

class PinSettingsSheet extends StatefulWidget {
  const PinSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const PinSettingsSheet(),
  );

  @override
  State<PinSettingsSheet> createState() => _PinSettingsSheetState();
}

class _PinSettingsSheetState extends State<PinSettingsSheet> {
  late Future<List<TrustedDevice>> _devices = _loadDevices();
  String? _feedback;

  Future<List<TrustedDevice>> _loadDevices() async {
    final result = await getIt<AuthSessionRepository>().getTrustedDevices();
    return result.fold((failure) => throw failure, (devices) => devices);
  }

  Future<String?> _askPin(String title) async {
    var value = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.padRight(4, '○').replaceAll(RegExp(r'\d'), '●'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              _PinPad(
                enabled: true,
                onDigit: (digit) {
                  if (value.length < 4) setDialogState(() => value += digit);
                },
                onBackspace: () {
                  if (value.isNotEmpty) {
                    setDialogState(
                      () => value = value.substring(0, value.length - 1),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: value.length == 4
                  ? () => Navigator.pop(dialogContext, value)
                  : null,
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    final first = await _askPin('Новый PIN');
    if (first == null || !mounted) return;
    final second = await _askPin('Повторите PIN');
    if (!mounted) return;
    if (first != second) {
      setState(() => _feedback = 'PIN-коды не совпали');
      return;
    }
    final result = await getIt<AuthSessionRepository>().changePin(first);
    if (!mounted) return;
    setState(
      () => _feedback = result.fold(_message, (_) => 'PIN изменён'),
    );
  }

  Future<void> _enablePin() async {
    final first = await _askPin('Создайте PIN');
    if (first == null || !mounted) return;
    final second = await _askPin('Повторите PIN');
    if (!mounted) return;
    if (first != second) {
      setState(() => _feedback = 'PIN-коды не совпали');
      return;
    }
    final result = await getIt<AuthSessionRepository>().enablePin(first);
    if (!mounted) return;
    setState(() {
      _feedback = result.fold(_message, (_) => 'PIN включён');
      _devices = _loadDevices();
    });
  }

  Future<void> _disablePin() async {
    final result = await getIt<AuthSessionRepository>().disablePin();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _feedback = _message(failure)),
      (_) => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionService>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingL,
        AppDimensions.paddingL,
        AppDimensions.paddingL,
        AppDimensions.paddingL + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Быстрый вход',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session.hasPinConfigured
                ? 'PIN включён на этом устройстве.'
                : 'PIN не настроен на этом устройстве.',
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!),
          ],
          if (session.hasPinConfigured) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _changePin,
              icon: const Icon(Icons.password_rounded),
              label: const Text('Изменить PIN'),
            ),
            TextButton.icon(
              onPressed: _disablePin,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Отключить PIN на этом устройстве'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _enablePin,
              icon: const Icon(Icons.pin_rounded),
              label: const Text('Включить PIN'),
            ),
          ],
          const Divider(height: 28),
          Text(
            'Доверенные устройства',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(
            height: 180,
            child: FutureBuilder<List<TrustedDevice>>(
              future: _devices,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Не удалось загрузить устройства'),
                  );
                }
                final devices = snapshot.data ?? const [];
                if (devices.isEmpty) {
                  return const Center(child: Text('Нет доверенных устройств'));
                }
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.smartphone_rounded),
                      title: Text(device.name),
                      subtitle: Text(
                        'Действует до ${_date(device.expiresAt)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Отозвать',
                        onPressed: () async {
                          final result = await getIt<AuthSessionRepository>()
                              .revokeTrustedDevice(device.id);
                          if (!mounted) return;
                          result.fold(
                            (failure) => setState(
                              () => _feedback = _message(failure),
                            ),
                            (_) => setState(() {
                              _devices = _loadDevices();
                              _feedback = 'Устройство отозвано';
                            }),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _message(Failure failure) => failure.message.isEmpty
    ? 'Не удалось выполнить действие. Попробуйте ещё раз.'
    : failure.message;

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
