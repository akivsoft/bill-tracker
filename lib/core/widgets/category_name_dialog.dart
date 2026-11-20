import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';

/// Shared category creation dialog used by feature category pickers.
class CategoryNameDialog extends StatefulWidget {
  const CategoryNameDialog({
    required this.title,
    required this.existing,
    required this.onSave,
    super.key,
  });

  final String title;
  final List<CategoryEntry> existing;
  final Future<CategoryEntry> Function(String name) onSave;

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  final TextEditingController _name = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: TextFormField(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          controller: _name,
          maxLength: 80,
          autofocus: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'Category name',
            errorText: _saveError,
          ),
          validator: (String? value) {
            final String normalized = value?.trim() ?? '';
            if (normalized.isEmpty) return 'Please enter a category name.';
            if (widget.existing.any(
              (CategoryEntry item) =>
                  item.name.trim().toLowerCase() == normalized.toLowerCase(),
            )) {
              return 'This category already exists.';
            }
            return null;
          },
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Save'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final CategoryEntry created = await widget.onSave(_name.text.trim());
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save category. Please try again.';
        });
      }
    }
  }
}
