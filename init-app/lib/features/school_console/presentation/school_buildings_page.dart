import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';
import 'package:mobile_template/features/school_console/presentation/school_buildings_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolBuildingsPage extends StatelessWidget {
  const SchoolBuildingsPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SchoolBuildingsCubit, SchoolBuildingsState>(
    listenWhen: (a, b) => a.revision != b.revision,
    listener: (context, state) {
      if (state.feedback != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.feedback!)));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: const AdminAppBar.school(sectionTitle: 'Корпуса'),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => _form(context),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Добавить корпус'),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<SchoolBuildingsCubit>().load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.getResponsivePadding(context),
            24,
            AppDimensions.getResponsivePadding(context),
            104,
          ),
          children: [
            Text(
              'Корпуса школы',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Добавляйте адреса и распределяйте классы, учителей и охрану по корпусам.',
            ),
            const SizedBox(height: 24),
            if (state.status == ManagedBuildingsStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.status == ManagedBuildingsStatus.failure)
              Center(
                child: TextButton.icon(
                  onPressed: context.read<SchoolBuildingsCubit>().load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить загрузку'),
                ),
              )
            else if (state.buildings.isEmpty)
              const GlassSurfaceCard(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.apartment_rounded, size: 56),
                    SizedBox(height: 12),
                    Text('Корпусов пока нет'),
                  ],
                ),
              )
            else
              ...state.buildings.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BuildingCard(
                    item: item,
                    busy: state.busyIds.contains(item.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _form(BuildContext context, [ManagedSchoolBuilding? item]) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<SchoolBuildingsCubit>(),
          child: _BuildingForm(item: item),
        ),
      );
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.item, required this.busy});
  final ManagedSchoolBuilding item;
  final bool busy;

  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        const CircleAvatar(child: Icon(Icons.apartment_rounded)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(item.address),
              Text(
                item.isActive ? 'Работает' : 'Отключён',
                style: TextStyle(
                  color: item.isActive ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        if (busy)
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          IconButton(
            tooltip: 'Изменить',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: context.read<SchoolBuildingsCubit>(),
                child: _BuildingForm(item: item),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: item.isActive ? 'Отключить' : 'Включить',
            onPressed: () => context.read<SchoolBuildingsCubit>().toggle(item),
            icon: Icon(
              item.isActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
            color: AppColors.error,
            onPressed: () async {
              final ok = await ConfirmationDialog.show(
                context,
                title: 'Удалить корпус?',
                content:
                    'Корпус «${item.name}» можно удалить только после переноса классов и сотрудников.',
                confirmText: 'Удалить',
              );
              if (ok == true && context.mounted) {
                await context.read<SchoolBuildingsCubit>().delete(item);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ],
    ),
  );
}

class _BuildingForm extends StatefulWidget {
  const _BuildingForm({this.item});
  final ManagedSchoolBuilding? item;
  @override
  State<_BuildingForm> createState() => _BuildingFormState();
}

class _BuildingFormState extends State<_BuildingForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name = TextEditingController(
    text: widget.item?.name,
  );
  late final TextEditingController address = TextEditingController(
    text: widget.item?.address,
  );
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Новый корпус' : 'Редактирование корпуса',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              GlobalTextFormField(
                controller: name,
                labelText: 'Название корпуса',
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: address,
                labelText: 'Адрес',
                validator: requiredText,
              ),
              const SizedBox(height: 20),
              BlocBuilder<SchoolBuildingsCubit, SchoolBuildingsState>(
                builder: (context, state) => GlobalButton(
                  text: 'Сохранить',
                  isLoading: state.isSaving,
                  onPressed: _save,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final saved = await context.read<SchoolBuildingsCubit>().save(
      id: widget.item?.id,
      name: name.text.trim(),
      address: address.text.trim(),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
