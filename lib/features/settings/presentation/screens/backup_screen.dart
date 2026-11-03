import 'dart:convert';
import 'dart:io';

import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/data/local/backup/local_backup_service.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/notifications/data/local_notification_service.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final TextEditingController _backupController = TextEditingController();
  String? _status;
  bool _working = false;

  @override
  void dispose() {
    _backupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup and restore')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.medium),
              child: Text(
                'Local backup files contain your financial records and settings. They stay on this device unless you choose to share them. Cloud synchronization is a separate, currently unavailable option.',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          FilledButton.icon(
            onPressed: _working ? null : _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Create and share backup'),
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            'Restore from backup',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.small),
          const Text(
            'Paste the contents of a MyFinance JSON backup below. The file is validated before anything changes. Restore replaces local financial data and cannot be undone.',
          ),
          const SizedBox(height: AppSpacing.small),
          TextField(
            controller: _backupController,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Backup JSON',
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton.icon(
            onPressed: _working ? null : _validateBackup,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Validate backup'),
          ),
          FilledButton.tonalIcon(
            onPressed: _working ? null : _restoreBackup,
            icon: const Icon(Icons.restore),
            label: const Text('Replace local data from backup'),
          ),
          if (_working) const LinearProgressIndicator(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_status!),
            ),
        ],
      ),
    ),
  );

  Future<void> _createBackup() async {
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      final String databaseJson = await ref
          .read(localBackupServiceProvider)
          .createBackup();
      final Map<String, Object?> envelope =
          jsonDecode(databaseJson) as Map<String, Object?>;
      final ReminderPreferences reminders = await LocalNotificationService()
          .loadPreferences();
      envelope['device_preferences'] = <String, Object?>{
        'reminders': reminders.toJson(),
      };
      final String json = const JsonEncoder.withIndent('  ').convert(envelope);
      final Directory directory = await getTemporaryDirectory();
      final File file = File(
        '${directory.path}/myfinance_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(json, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'MyFinance local backup',
        ),
      );
      if (mounted) {
        setState(() => _status = 'Backup created. Store it somewhere safe.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _validateBackup() async {
    try {
      final BackupValidation validation = ref
          .read(localBackupServiceProvider)
          .validate(_backupController.text);
      setState(
        () => _status =
            'Valid version 1 backup · ${validation.recordCount} records across ${validation.tables.length} tables.',
      );
    } catch (error) {
      setState(() => _status = 'Backup validation failed: $error');
    }
  }

  Future<void> _restoreBackup() async {
    final String contents = _backupController.text;
    try {
      final BackupValidation validation = ref
          .read(localBackupServiceProvider)
          .validate(contents);
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace local data?'),
          content: Text(
            'This will replace existing financial records and settings with ${validation.recordCount} backup records. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace data'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _working = true;
        _status = null;
      });
      await ref.read(localBackupServiceProvider).restoreReplacing(contents);
      final Map<String, Object?> envelope =
          jsonDecode(contents) as Map<String, Object?>;
      final Object? devicePreferences = envelope['device_preferences'];
      if (devicePreferences is Map<String, Object?> &&
          devicePreferences['reminders'] is Map<String, Object?>) {
        await LocalNotificationService().savePreferences(
          ReminderPreferences.fromJson(
            devicePreferences['reminders']! as Map<String, Object?>,
          ),
        );
      }
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(walletManagementAccountsProvider);
      ref.invalidate(incomeOverviewProvider);
      ref.invalidate(expensesOverviewProvider);
      ref.invalidate(billsOverviewProvider);
      ref.invalidate(billPaymentsOverviewProvider);
      ref.invalidate(loansOverviewProvider);
      ref.invalidate(installmentsOverviewProvider);
      ref.invalidate(loanPaymentsOverviewProvider);
      ref.invalidate(savingsGoalsOverviewProvider);
      ref.invalidate(paydaySchedulesProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(dashboardRecentTransactionsProvider);
      ref.invalidate(dashboardTransactionsProvider);
      if (mounted) {
        setState(
          () => _status =
              'Restore completed. Financial records and settings were restored.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = 'Restore failed. Local data was not changed: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
