import 'package:bill_tracker/app/config/app_config.dart';
import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/section_header.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/presentation/providers/authentication_provider.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<(String, String)> _currencies = <(String, String)>[
    ('PHP', 'PHP · Philippine peso'),
    ('USD', 'USD · US dollar'),
    ('SGD', 'SGD · Singapore dollar'),
    ('EUR', 'EUR · Euro'),
    ('GBP', 'GBP · Pound sterling'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserPreferences> preferencesValue = ref.watch(
      userPreferencesProvider,
    );
    final AuthenticationState auth = ref.watch(authenticationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: preferencesValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) =>
                  Center(child: Text('Settings could not be loaded: $error')),
              data: (UserPreferences preferences) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.small,
                  AppSpacing.medium,
                  AppSpacing.large,
                ),
                children: <Widget>[
                  const SectionHeader(title: 'Profile'),
                  const SizedBox(height: AppSpacing.small),
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          title: Text(
                            preferences.displayName?.isNotEmpty == true
                                ? preferences.displayName!
                                : 'Add a display name',
                          ),
                          subtitle: Text(
                            auth.email ??
                                (auth.isAuthenticated
                                    ? 'Supabase account'
                                    : 'Local-only account'),
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit display name',
                            onPressed: () =>
                                _editDisplayName(context, ref, preferences),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            auth.isAuthenticated
                                ? Icons.cloud_done_outlined
                                : Icons.phone_iphone_rounded,
                          ),
                          title: Text(
                            auth.isAuthenticated
                                ? 'Supabase account'
                                : 'Local-only mode',
                          ),
                          subtitle: Text(
                            auth.isAuthenticated
                                ? 'Local records are not automatically merged.'
                                : 'No account or internet connection is required.',
                          ),
                          trailing: TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    if (auth.isAuthenticated) {
                                      await ref
                                          .read(authenticationProvider.notifier)
                                          .signOut();
                                    } else {
                                      context.push(
                                        RouteNames.authenticationPath,
                                      );
                                    }
                                  },
                            child: Text(
                              auth.isAuthenticated ? 'Sign out' : 'Sign in',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const SectionHeader(title: 'Preferences'),
                  const SizedBox(height: AppSpacing.small),
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: preferences.currencyCode,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.currency_exchange_rounded),
                          ),
                          items: _currencies
                              .map(
                                ((String, String) currency) =>
                                    DropdownMenuItem<String>(
                                      value: currency.$1,
                                      child: Text(currency.$2),
                                    ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              _savePersonalPreferences(
                                ref,
                                preferences.copyWith(currencyCode: value),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        DropdownButtonFormField<String>(
                          initialValue: preferences.dateFormat,
                          decoration: const InputDecoration(
                            labelText: 'Date format',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'MM/dd/yyyy',
                              child: Text('MM/DD/YYYY'),
                            ),
                            DropdownMenuItem(
                              value: 'dd/MM/yyyy',
                              child: Text('DD/MM/YYYY'),
                            ),
                            DropdownMenuItem(
                              value: 'yyyy-MM-dd',
                              child: Text('YYYY-MM-DD'),
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value != null) {
                              _savePersonalPreferences(
                                ref,
                                preferences.copyWith(dateFormat: value),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        DropdownButtonFormField<int>(
                          initialValue: preferences.firstDayOfWeek,
                          decoration: const InputDecoration(
                            labelText: 'First day of the week',
                            prefixIcon: Icon(Icons.view_week_outlined),
                          ),
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem(
                              value: DateTime.monday,
                              child: Text('Monday'),
                            ),
                            DropdownMenuItem(
                              value: DateTime.sunday,
                              child: Text('Sunday'),
                            ),
                          ],
                          onChanged: (int? value) {
                            if (value != null) {
                              _savePersonalPreferences(
                                ref,
                                preferences.copyWith(firstDayOfWeek: value),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Appearance',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment(
                              value: 'system',
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: 'light',
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: 'dark',
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: <String>{preferences.themeMode},
                          onSelectionChanged: (Set<String> value) => ref
                              .read(userPreferencesProvider.notifier)
                              .setThemeMode(value.first),
                        ),
                        const Divider(height: AppSpacing.large),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.translate_rounded),
                          title: Text('Language'),
                          subtitle: Text(
                            'English · More languages will be added later.',
                          ),
                          trailing: Icon(Icons.lock_outline_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const SectionHeader(title: 'Security'),
                  const SizedBox(height: AppSpacing.small),
                  _PlaceholderSettingsCard(
                    items: const <(IconData, String, String)>[
                      (
                        Icons.pin_outlined,
                        'App PIN',
                        'Not set up in this version.',
                      ),
                      (
                        Icons.fingerprint_rounded,
                        'Biometric authentication',
                        'Not set up in this version.',
                      ),
                      (
                        Icons.privacy_tip_outlined,
                        'Privacy settings',
                        'Privacy controls will be available in a later phase.',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const SectionHeader(title: 'Data'),
                  const SizedBox(height: AppSpacing.small),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        const ListTile(
                          leading: Icon(Icons.storage_rounded),
                          title: Text('Local database'),
                          subtitle: Text(
                            'Your financial records remain stored on this device.',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.backup_outlined),
                          title: const Text('Backup and restore'),
                          subtitle: const Text(
                            'Create a local backup or restore after validation.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(RouteNames.moreModule('backup')),
                        ),
                        ListTile(
                          leading: const Icon(Icons.insert_chart_outlined),
                          title: const Text('Export reports'),
                          subtitle: const Text(
                            'Share filtered reports as PDF, Excel, or CSV.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(RouteNames.moreModule('reports')),
                        ),
                        const ListTile(
                          leading: Icon(Icons.sync_rounded),
                          title: Text('Cloud synchronization'),
                          subtitle: Text(
                            'Unavailable until an authenticated financial data sync backend is configured. Nothing is uploaded.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const SectionHeader(title: 'Application'),
                  const SizedBox(height: AppSpacing.small),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.info_outline_rounded),
                          title: const Text('About MyFinance'),
                          subtitle: const Text(
                            'Personal finance, bills, and commitments.',
                          ),
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: AppConfig.displayName,
                            applicationVersion: '1.0.0',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.school_outlined),
                          title: const Text('Replay introduction'),
                          subtitle: const Text(
                            'Show the three onboarding screens again.',
                          ),
                          onTap: () => _resetOnboarding(context, ref),
                        ),
                        const ListTile(
                          leading: Icon(Icons.policy_outlined),
                          title: Text('Privacy policy and terms'),
                          subtitle: Text(
                            'Information pages are not available yet.',
                          ),
                          trailing: Icon(Icons.open_in_new_rounded, size: 18),
                        ),
                        const ListTile(
                          leading: Icon(Icons.tag_rounded),
                          title: Text('Version'),
                          trailing: Text('1.0.0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: preferences.displayName ?? '',
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Name or nickname'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _savePersonalPreferences(
      ref,
      preferences.copyWith(
        displayName: value.trim().isEmpty ? null : value.trim(),
        clearDisplayName: value.trim().isEmpty,
      ),
    );
  }

  Future<void> _savePersonalPreferences(
    WidgetRef ref,
    UserPreferences preferences,
  ) => ref
      .read(userPreferencesProvider.notifier)
      .savePersonalPreferences(
        displayName: preferences.displayName,
        countryCode: preferences.countryCode,
        currencyCode: preferences.currencyCode,
        firstDayOfWeek: preferences.firstDayOfWeek,
        dateFormat: preferences.dateFormat,
      );

  Future<void> _resetOnboarding(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Replay the introduction?'),
        content: const Text(
          'Your saved preferences and financial records will stay on this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replay'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(userPreferencesProvider.notifier).resetOnboarding();
    if (context.mounted) context.go(RouteNames.onboardingPath);
  }
}

class _PlaceholderSettingsCard extends StatelessWidget {
  const _PlaceholderSettingsCard({required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: items
          .map(
            ((IconData, String, String) item) => ListTile(
              leading: Icon(item.$1),
              title: Text(item.$2),
              subtitle: Text(item.$3),
              trailing: const Icon(Icons.info_outline_rounded, size: 18),
            ),
          )
          .toList(growable: false),
    ),
  );
}
