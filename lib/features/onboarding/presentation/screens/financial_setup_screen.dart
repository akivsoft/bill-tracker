import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/wallets/presentation/widgets/account_entry_sheet.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FinancialSetupScreen extends ConsumerStatefulWidget {
  const FinancialSetupScreen({super.key});

  @override
  ConsumerState<FinancialSetupScreen> createState() =>
      _FinancialSetupScreenState();
}

class _FinancialSetupScreenState extends ConsumerState<FinancialSetupScreen> {
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();

  int _step = 0;
  int _firstDayOfWeek = DateTime.monday;
  String _countryCode = 'PH';
  String _currencyCode = 'PHP';
  String _dateFormat = 'MM/dd/yyyy';
  String? _incomeFrequency;
  bool _saving = false;
  bool _preferencesLoaded = false;

  static const List<(String, String)> _currencies = <(String, String)>[
    ('PHP', 'PHP · Philippine peso'),
    ('USD', 'USD · US dollar'),
    ('SGD', 'SGD · Singapore dollar'),
    ('EUR', 'EUR · Euro'),
    ('GBP', 'GBP · Pound sterling'),
  ];

  static const List<(String, String)> _incomeFrequencies = <(String, String)>[
    ('daily', 'Daily'),
    ('weekly', 'Weekly'),
    ('biweekly', 'Biweekly'),
    ('twice_monthly', 'Twice a month'),
    ('monthly', 'Monthly'),
    ('irregular', 'Irregular income'),
    ('multiple', 'Multiple income sources'),
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _loadPreferences(UserPreferences preferences) {
    if (_preferencesLoaded) return;
    _preferencesLoaded = true;
    _displayNameController.text = preferences.displayName ?? '';
    _countryCode = preferences.countryCode;
    _currencyCode = preferences.currencyCode;
    _firstDayOfWeek = preferences.firstDayOfWeek;
    _dateFormat = preferences.dateFormat;
    _incomeFrequency = preferences.incomeFrequency;
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_step == 0 && !(_personalFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_step == 0) {
        await ref
            .read(userPreferencesProvider.notifier)
            .savePersonalPreferences(
              displayName: _displayNameController.text,
              countryCode: _countryCode,
              currencyCode: _currencyCode,
              firstDayOfWeek: _firstDayOfWeek,
              dateFormat: _dateFormat,
            );
      } else if (_step == 1) {
        await ref
            .read(userPreferencesProvider.notifier)
            .saveIncomeFrequency(_incomeFrequency);
      } else if (_step == 2) {
        final CreateAccountInput? input =
            await showModalBottomSheet<CreateAccountInput>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (BuildContext context) =>
                  AccountEntrySheet(currencyCode: _currencyCode),
            );
        if (input == null) return;
        await ref.read(financialRepositoryProvider).createAccount(input);
      } else {
        await ref.read(userPreferencesProvider.notifier).completeSetup();
        if (mounted) context.go(RouteNames.homePath);
        return;
      }
      if (mounted) setState(() => _step += 1);
    } catch (error) {
      _showMessage('Could not save this step. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skipCurrentStep() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_step == 1) {
        await ref
            .read(userPreferencesProvider.notifier)
            .saveIncomeFrequency(null);
      }
      if (mounted) setState(() => _step += 1);
    } catch (error) {
      _showMessage('Could not save this step. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserPreferences> preferences = ref.watch(
      userPreferencesProvider,
    );
    return preferences.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Set up MyFinance')),
        body: Center(child: Text('Could not load your preferences: $error')),
      ),
      data: (UserPreferences value) {
        _loadPreferences(value);
        return _buildWizard(context);
      },
    );
  }

  Widget _buildWizard(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Set up MyFinance'),
        leading: _step == 0
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: _saving ? null : () => setState(() => _step -= 1),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.small,
                    AppSpacing.medium,
                    AppSpacing.medium,
                  ),
                  child: Row(
                    children: List<Widget>.generate(4, (int index) {
                      final bool active = index <= _step;
                      return Expanded(
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.only(
                            right: AppSpacing.small,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? colors.primary
                                : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      0,
                      AppSpacing.medium,
                      AppSpacing.large,
                    ),
                    child: _stepContent(context),
                  ),
                ),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context) => switch (_step) {
    0 => _personalStep(context),
    1 => _incomeStep(context),
    2 => _accountStep(context),
    _ => _finishStep(context),
  };

  Widget _personalStep(BuildContext context) => Form(
    key: _personalFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Your preferences',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'You can change these choices any time in Settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.large),
        TextFormField(
          controller: _displayNameController,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Display name or nickname',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        DropdownButtonFormField<String>(
          initialValue: _countryCode,
          decoration: const InputDecoration(labelText: 'Country'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'PH', child: Text('Philippines')),
            DropdownMenuItem(value: 'US', child: Text('United States')),
            DropdownMenuItem(value: 'SG', child: Text('Singapore')),
            DropdownMenuItem(value: 'GB', child: Text('United Kingdom')),
          ],
          onChanged: (String? value) =>
              setState(() => _countryCode = value ?? 'PH'),
        ),
        const SizedBox(height: AppSpacing.medium),
        DropdownButtonFormField<String>(
          initialValue: _currencyCode,
          decoration: const InputDecoration(labelText: 'Preferred currency'),
          items: _currencies
              .map(
                ((String, String) item) => DropdownMenuItem<String>(
                  value: item.$1,
                  child: Text(item.$2),
                ),
              )
              .toList(),
          onChanged: (String? value) =>
              setState(() => _currencyCode = value ?? 'PHP'),
        ),
        const SizedBox(height: AppSpacing.medium),
        DropdownButtonFormField<int>(
          initialValue: _firstDayOfWeek,
          decoration: const InputDecoration(labelText: 'First day of the week'),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
            DropdownMenuItem(value: DateTime.sunday, child: Text('Sunday')),
          ],
          onChanged: (int? value) =>
              setState(() => _firstDayOfWeek = value ?? DateTime.monday),
        ),
        const SizedBox(height: AppSpacing.medium),
        DropdownButtonFormField<String>(
          initialValue: _dateFormat,
          decoration: const InputDecoration(labelText: 'Date format'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')),
            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')),
            DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')),
          ],
          onChanged: (String? value) =>
              setState(() => _dateFormat = value ?? 'MM/dd/yyyy'),
        ),
      ],
    ),
  );

  Widget _incomeStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        'How often are you paid?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.small),
      Text(
        'This helps shape your planner. You do not need to enter a salary.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.large),
      DropdownButtonFormField<String>(
        initialValue: _incomeFrequency,
        decoration: const InputDecoration(
          labelText: 'Income frequency',
          prefixIcon: Icon(Icons.schedule_rounded),
        ),
        hint: const Text('Choose an option'),
        items: _incomeFrequencies
            .map(
              ((String, String) item) => DropdownMenuItem<String>(
                value: item.$1,
                child: Text(item.$2),
              ),
            )
            .toList(),
        onChanged: (String? value) => setState(() => _incomeFrequency = value),
      ),
    ],
  );

  Widget _accountStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        'Add your first account',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.small),
      Text(
        'Start with a balance you know. You can add more accounts later. Credit card balances stay separate from available money.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.large),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.small),
            const Text('Add only balances you want to track.'),
          ],
        ),
      ),
    ],
  );

  Widget _finishStep(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xLarge),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 56,
            color: colors.onTertiaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.large),
        Text(
          'You’re all set',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'Add, edit, and manage your financial information whenever you need it. Your data stays on this device in local-only mode.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.medium,
      AppSpacing.small,
      AppSpacing.medium,
      AppSpacing.medium,
    ),
    child: Row(
      children: <Widget>[
        if (_step == 1 || _step == 2)
          TextButton(
            onPressed: _saving ? null : _skipCurrentStep,
            child: Text(_step == 1 ? 'Skip this step' : 'Skip account'),
          )
        else if (_step > 0)
          TextButton(
            onPressed: _saving ? null : () => setState(() => _step -= 1),
            child: const Text('Back'),
          )
        else
          const SizedBox(width: 100),
        const Spacer(),
        FilledButton.icon(
          onPressed: _saving ? null : _continue,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _step == 3
                      ? Icons.check_rounded
                      : _step == 2
                      ? Icons.add_rounded
                      : Icons.arrow_forward_rounded,
                ),
          label: Text(
            _step == 3
                ? 'Go to dashboard'
                : _step == 2
                ? 'Add account'
                : 'Continue',
          ),
        ),
      ],
    ),
  );
}
