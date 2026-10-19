import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/account_deletion/presentation/account_deletion_cubit.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});
  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _visible = false;
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AccountDeletionCubit, AccountDeletionState>(
    listener: (context, state) {
      if (state.deleted) {
        _password.clear();
        Navigator.of(context).pop(true);
      }
    },
    builder: (context, state) => PopScope(
      canPop: !state.deleting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.accountDeletionTitle),
          automaticallyImplyLeading: !state.deleting,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppDimensions.paddingAllL,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.accountDeletionIntro),
                    const SizedBox(height: 20),
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.failure != null) ...[
                      Text(
                        state.failure!.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (state.info == null)
                        TextButton(
                          onPressed: () =>
                              context.read<AccountDeletionCubit>().load(),
                          child: Text(context.l10n.retry),
                        ),
                      const SizedBox(height: 20),
                    ],
                    if (state.info?.central == true) ...[
                      Text(context.l10n.accountDeletionCentral),
                      const SizedBox(height: 20),
                    ],
                    if (state.info?.canDelete == false)
                      Text(context.l10n.accountDeletionLastAdmin),
                    if (state.info?.canDelete == true) ...[
                      TextField(
                        controller: _password,
                        enabled: !state.deleting,
                        obscureText: !_visible,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: context.l10n.accountDeletionPassword,
                          suffixIcon: IconButton(
                            tooltip: _visible
                                ? context.l10n.hidePassword
                                : context.l10n.showPassword,
                            onPressed: state.deleting
                                ? null
                                : () => setState(() => _visible = !_visible),
                            icon: Icon(
                              _visible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _confirmation,
                        enabled: !state.deleting,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: context.l10n.accountDeletionConfirm,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: state.deleting
                            ? null
                            : () => context.read<AccountDeletionCubit>().delete(
                                _password.text,
                                _confirmation.text,
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                          minimumSize: const Size(48, 52),
                        ),
                        icon: state.deleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever_outlined),
                        label: Text(context.l10n.deleteAccount),
                      ),
                    ],
                    const SizedBox(height: 24),
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
