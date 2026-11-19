import 'package:flutter/material.dart';

/// Keeps a save action pending until its asynchronous write succeeds.
///
/// The containing form remains mounted after validation or persistence errors,
/// so the user can correct the input or retry without losing entered values.
class AsyncSaveButton extends StatefulWidget {
  const AsyncSaveButton({
    required this.label,
    required this.onSave,
    this.icon,
    this.validate,
    this.result = true,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Future<void> Function() onSave;
  final bool Function()? validate;
  final Object? result;

  @override
  State<AsyncSaveButton> createState() => _AsyncSaveButtonState();
}

class _AsyncSaveButtonState extends State<AsyncSaveButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || (widget.validate != null && !widget.validate!())) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(widget.result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String label = _saving ? 'Saving…' : widget.label;
    if (widget.icon != null) {
      return FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: Icon(widget.icon),
        label: Text(label),
      );
    }
    return FilledButton(onPressed: _saving ? null : _save, child: Text(label));
  }
}
