import 'package:flutter_riverpod/flutter_riverpod.dart';

final NotifierProvider<DashboardSectionState, Map<String, bool>>
dashboardSectionStateProvider =
    NotifierProvider<DashboardSectionState, Map<String, bool>>(
      DashboardSectionState.new,
    );

/// Keeps dashboard disclosure state while users move between app routes.
class DashboardSectionState extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const <String, bool>{};

  bool isExpanded(String sectionId) => state[sectionId] ?? true;

  void toggle(String sectionId) {
    state = <String, bool>{...state, sectionId: !isExpanded(sectionId)};
  }
}
