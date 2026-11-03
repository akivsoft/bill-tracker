import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _saving = false;

  static const List<_OnboardingPage> _pages = <_OnboardingPage>[
    _OnboardingPage(
      title: 'Manage your money',
      description:
          'Keep the accounts you use every day together and see what is available at a glance.',
      icon: Icons.account_balance_wallet_rounded,
      points: <String>[
        'Cash and bank accounts',
        'E-wallets and debit cards',
        'Credit card balances kept separate',
      ],
    ),
    _OnboardingPage(
      title: 'Stay on top of payments',
      description:
          'Organize the commitments coming up, then record a payment when you make it.',
      icon: Icons.event_available_rounded,
      points: <String>[
        'Bills and recurring expenses',
        'Loan installments',
        'Credit card payments and reminders',
      ],
    ),
    _OnboardingPage(
      title: 'Plan your finances',
      description:
          'Plan around your income and understand how much remains after commitments.',
      icon: Icons.insights_rounded,
      points: <String>[
        'Salary allocations and income',
        'Expenses and savings goals',
        'Financial summaries and reports',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userPreferencesProvider.notifier).completeOnboarding();
      if (mounted) context.go(RouteNames.setupPath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save onboarding yet. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_pageIndex == _pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                AppSpacing.medium,
              ),
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : _finish,
                      child: const Text('Skip'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (int index) =>
                          setState(() => _pageIndex = index),
                      itemBuilder: (BuildContext context, int index) =>
                          _OnboardingPageView(page: _pages[index]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Semantics(
                    label: 'Page ${_pageIndex + 1} of ${_pages.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_pages.length, (
                        int index,
                      ) {
                        final bool selected = index == _pageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: selected ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primary
                                : colors.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Row(
                    children: <Widget>[
                      if (_pageIndex > 0)
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 96),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving ? null : _next,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _pageIndex == _pages.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(
                          _pageIndex == _pages.length - 1
                              ? 'Get started'
                              : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: AppSpacing.large),
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Icon(page.icon, size: 76, color: colors.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.large),
          ...page.points.map(
            (String point) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, color: colors.tertiary),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(child: Text(point)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> points;
}
