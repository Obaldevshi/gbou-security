import 'package:flutter/material.dart';
import 'package:mobile_template/core/utils/app_navigator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_cubit.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _hidden = true;
  int? _building;
  String _role = 'primary';
  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.qrSetupTitle)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BlocBuilder<PairingCubit, PairingState>(
            builder: (context, s) {
              final l = context.l10n;
              final cubit = context.read<PairingCubit>();
              final school = s.school;
              final selectedBuilding =
                  school?.buildings.any((b) => b.id == _building) == true
                  ? _building
                  : null;
              final padding = AppLayoutItemBuilder.values(
                wide: 28.0,
                narrow: 16.0,
              )(context);
              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  Text(l.qrSetupScopeHint),
                  const SizedBox(height: 16),
                  if (s.busy) const LinearProgressIndicator(),
                  if (s.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        s.error!.isEmpty ? l.errorServer : s.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (s.session == null) ...[
                    Text(l.qrSetupLoginHint),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _login,
                      enabled: !s.busy,
                      autofillHints: const [],
                      decoration: InputDecoration(labelText: l.qrSetupLogin),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !s.busy,
                      obscureText: _hidden,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [],
                      decoration: InputDecoration(
                        labelText: l.qrSetupPassword,
                        suffixIcon: IconButton(
                          tooltip: l.qrSetupShowPassword,
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: s.busy
                          ? null
                          : () {
                              final password = _password.text;
                              _password.clear();
                              cubit.login(_login.text, password);
                            },
                      child: Text(l.qrSetupEnter),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: s.busy
                            ? null
                            : () {
                                _password.clear();
                                _code.clear();
                                _building = null;
                                cubit.logout();
                              },
                        child: Text(l.qrSetupLogout),
                      ),
                    ),
                    if (s.session!.passwordChangeRequired) ...[
                      Text(l.qrSetupNewPasswordHint),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        enabled: !s.busy,
                        obscureText: _hidden,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l.qrSetupNewPassword,
                          suffixIcon: IconButton(
                            tooltip: l.qrSetupShowPassword,
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: s.busy
                            ? null
                            : () {
                                final password = _password.text;
                                _password.clear();
                                cubit.changePassword(password);
                              },
                        child: Text(l.qrSetupSavePassword),
                      ),
                    ] else ...[
                      if (s.schools.isEmpty) Text(l.qrSetupNoSchools),
                      DropdownButtonFormField<int>(
                        key: ValueKey('school-${s.schoolId}'),
                        initialValue: s.schoolId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.qrSetupSchool),
                        items: s.schools
                            .map(
                              (x) => DropdownMenuItem(
                                value: x.id,
                                child: Text(
                                  x.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: s.busy
                            ? null
                            : (id) {
                                if (id != null) {
                                  setState(() {
                                    _building = null;
                                    _role = 'primary';
                                  });
                                  cubit.selectSchool(id);
                                }
                              },
                      ),
                      if (school != null) ...[
                        const SizedBox(height: 16),
                        SelectableText('https://${school.hostname}'),
                        OutlinedButton.icon(
                          onPressed: s.busy
                              ? null
                              : () => cubit.selectSchool(s.schoolId!),
                          icon: const Icon(Icons.refresh),
                          label: Text(l.schoolDevicesRefresh),
                        ),
                        if (s.done)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l.qrSetupDone),
                          ),
                        if (s.preview != null) ...[
                          const Divider(height: 32),
                          Text(
                            s.preview!.label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${l.qrSetupFingerprint}: ${s.preview!.fingerprint}',
                          ),
                          Text(
                            '${l.qrSetupExpires}: ${s.preview!.expiresAt.toLocal()}',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'building-${s.schoolId}-$selectedBuilding',
                            ),
                            initialValue: selectedBuilding,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.qrSetupBuilding,
                            ),
                            items: school.buildings
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      b.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: s.busy
                                ? null
                                : (id) => setState(() => _building = id),
                          ),
                          if (school.buildings.isEmpty)
                            Text(l.qrSetupNoBuildings),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('role-${s.schoolId}-$_role'),
                            initialValue: _role,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.qrSetupRole,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'primary',
                                child: Text(
                                  l.schoolDevicesPrimary,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'terminal',
                                enabled: school.hasPrimary,
                                child: Text(
                                  l.schoolDevicesTerminal,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: s.busy
                                ? null
                                : (role) =>
                                      setState(() => _role = role ?? 'primary'),
                          ),
                          const SizedBox(height: 16),
                          Text(l.qrSetupCodeHint),
                          TextField(
                            controller: _code,
                            enabled: !s.busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(
                              labelText: l.qrSetupCode,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed:
                                s.busy ||
                                    selectedBuilding == null ||
                                    _code.text.length != 6 ||
                                    (_role == 'terminal' && !school.hasPrimary)
                                ? null
                                : () => _approve(context, selectedBuilding),
                            child: Text(l.qrSetupApprove),
                          ),
                        ] else if (!s.done)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l.qrSetupScanHint),
                          ),
                        const Divider(height: 32),
                        Text(
                          l.schoolDevicesTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (school.devices.isEmpty) Text(l.schoolDevicesEmpty),
                        for (final d in school.devices)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    d.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    d.role == 'primary'
                                        ? l.schoolDevicesPrimary
                                        : l.schoolDevicesTerminal,
                                  ),
                                  Text(switch (d.state) {
                                    'active' => l.schoolDevicesActive,
                                    'pending' => l.schoolDevicesPending,
                                    _ => l.schoolDevicesRevoked,
                                  }),
                                  Text(
                                    '${l.qrSetupBuilding}: ${_buildingName(school, d.buildingId, l.qrSetupUnassigned)}',
                                  ),
                                  if (d.role == 'primary' &&
                                      d.state == 'pending')
                                    TextButton(
                                      onPressed: s.busy
                                          ? null
                                          : () => _activate(context, d.id),
                                      child: Text(l.schoolDevicesActivate),
                                    ),
                                  if (d.role == 'terminal' &&
                                      d.state == 'active')
                                    TextButton(
                                      onPressed: s.busy
                                          ? null
                                          : () => _revoke(context, d.id),
                                      child: Text(l.schoolDevicesRevoke),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  String _buildingName(PairingSchool school, int? id, String fallback) {
    for (final b in school.buildings) {
      if (b.id == id) return b.name;
    }
    return fallback;
  }

  Future<void> _approve(BuildContext context, int building) async {
    final cubit = context.read<PairingCubit>();
    final l = context.l10n;
    final state = cubit.state;
    final school = state.schools.firstWhere((s) => s.id == state.schoolId).name;
    final confirmed = await showDialog<bool>(
      context: appNavigator(context).context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        title: Text(l.qrSetupApprove),
        content: Text(
          '${l.qrSetupConfirmHint}\n\n$school\n${_buildingName(state.school!, building, l.qrSetupUnassigned)}\n${_role == 'primary' ? l.schoolDevicesPrimary : l.schoolDevicesTerminal}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.schoolDevicesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.qrSetupApprove),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && !cubit.isClosed) {
      await cubit.approve(building, _role, _code.text);
      if (mounted) _code.clear();
    }
  }

  Future<void> _activate(BuildContext context, String device) async {
    final cubit = context.read<PairingCubit>();
    final l = context.l10n;
    var stopped = false;
    var restored = false;
    final confirmed = await showDialog<bool>(
      context: appNavigator(context).context,
      useRootNavigator: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(l.schoolDevicesActivate),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.schoolDevicesCutoverWarning),
                  CheckboxListTile(
                    value: stopped,
                    onChanged: (v) => update(() => stopped = v ?? false),
                    title: Text(l.schoolDevicesStopped),
                  ),
                  CheckboxListTile(
                    value: restored,
                    onChanged: (v) => update(() => restored = v ?? false),
                    title: Text(l.schoolDevicesRestored),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.schoolDevicesCancel),
            ),
            FilledButton(
              onPressed: stopped && restored
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: Text(l.schoolDevicesActivate),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.activate(device);
  }

  Future<void> _revoke(BuildContext context, String device) async {
    final cubit = context.read<PairingCubit>();
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: appNavigator(context).context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        title: Text(l.schoolDevicesRevoke),
        content: Text(l.schoolDevicesRevokeHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.schoolDevicesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.schoolDevicesRevoke),
          ),
        ],
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.revoke(device);
  }
}
