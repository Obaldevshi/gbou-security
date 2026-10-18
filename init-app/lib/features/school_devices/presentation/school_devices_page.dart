import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/school_devices/domain/school_devices.dart';
import 'package:mobile_template/features/school_devices/presentation/school_devices_cubit.dart';

class SchoolDevicesPage extends StatelessWidget {
  const SchoolDevicesPage({required this.schoolName, super.key});
  final String schoolName;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(schoolName)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BlocBuilder<SchoolDevicesCubit, SchoolDevicesState>(
            builder: (context, state) {
              final l10n = context.l10n;
              final cubit = context.read<SchoolDevicesCubit>();
              final data = state.overview;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l10n.schoolDevicesTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.schoolDevicesExplanation),
                  const SizedBox(height: 16),
                  if (state.busy) const LinearProgressIndicator(),
                  if (state.error != null) ...[
                    Text(
                      state.error!.isEmpty ? l10n.errorServer : state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: state.busy ? null : cubit.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.schoolDevicesRefresh),
                  ),
                  if (data != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      'https://${data.hostname}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(l10n.schoolDevicesAddressHint),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => cubit.invite('primary'),
                      icon: const Icon(Icons.dns_outlined),
                      label: Text(l10n.schoolDevicesInvitePrimary),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          state.busy ||
                              !data.devices.any(
                                (d) =>
                                    d.role == 'primary' && d.state == 'active',
                              )
                          ? null
                          : () => cubit.invite('terminal'),
                      icon: const Icon(Icons.touch_app_outlined),
                      label: Text(l10n.schoolDevicesInviteTerminal),
                    ),
                    if (state.invitation case final invitation?) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.schoolDevicesInvitationHint),
                              const SizedBox(height: 12),
                              SelectableText(invitation.code),
                              Text('${invitation.expiresAt.toLocal()}'),
                              TextButton(
                                onPressed: cubit.hideInvitation,
                                child: Text(l10n.schoolDevicesHideCode),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (data.devices.isEmpty) Text(l10n.schoolDevicesEmpty),
                    for (final device in data.devices)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                device.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                device.role == 'primary'
                                    ? l10n.schoolDevicesPrimary
                                    : l10n.schoolDevicesTerminal,
                              ),
                              Text(switch (device.state) {
                                'active' => l10n.schoolDevicesActive,
                                'pending' => l10n.schoolDevicesPending,
                                _ => l10n.schoolDevicesRevoked,
                              }),
                              if (device.role == 'primary' &&
                                  device.state == 'pending')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => _activate(context, device),
                                  child: Text(l10n.schoolDevicesActivate),
                                ),
                              if (device.role == 'terminal' &&
                                  device.state != 'revoked')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => _revoke(context, device),
                                  child: Text(l10n.schoolDevicesRevoke),
                                ),
                            ],
                          ),
                        ),
                      ),
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

  Future<void> _activate(BuildContext context, SchoolDevice device) async {
    var stopped = false;
    var restored = false;
    final cubit = context.read<SchoolDevicesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: Text(dialog.l10n.schoolDevicesActivate),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dialog.l10n.schoolDevicesCutoverWarning),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: stopped,
                    onChanged: (v) => setState(() => stopped = v ?? false),
                    title: Text(dialog.l10n.schoolDevicesStopped),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: restored,
                    onChanged: (v) => setState(() => restored = v ?? false),
                    title: Text(dialog.l10n.schoolDevicesRestored),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(dialog.l10n.schoolDevicesCancel),
            ),
            FilledButton(
              onPressed: stopped && restored
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: Text(dialog.l10n.schoolDevicesActivate),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.activate(device.id);
  }

  Future<void> _revoke(BuildContext context, SchoolDevice device) async {
    final cubit = context.read<SchoolDevicesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.schoolDevicesRevoke),
        content: Text(dialog.l10n.schoolDevicesRevokeHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(dialog.l10n.schoolDevicesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(dialog.l10n.schoolDevicesRevoke),
          ),
        ],
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.revoke(device.id);
  }
}
