import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: const Center(child: CircularProgressIndicator()),
  );
}
