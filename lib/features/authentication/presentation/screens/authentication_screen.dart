import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/features/authentication/domain/entities/auth_session.dart';
import 'package:bill_tracker/features/authentication/presentation/providers/authentication_provider.dart';
import 'package:bill_tracker/features/shared/presentation/widgets/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum AuthFlow { signIn, signUp, forgotPassword }

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({this.flow = AuthFlow.signIn, super.key});

  final AuthFlow flow;

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _passwordVisible = false;
  bool _confirmationVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) => validatePassword(value);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthenticationController controller = ref.read(
      authenticationProvider.notifier,
    );
    switch (widget.flow) {
      case AuthFlow.signIn:
        await controller.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      case AuthFlow.signUp:
        await controller.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      case AuthFlow.forgotPassword:
        await controller.sendPasswordReset(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthenticationState auth = ref.watch(authenticationProvider);
    final bool signUp = widget.flow == AuthFlow.signUp;
    final bool forgot = widget.flow == AuthFlow.forgotPassword;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(forgot ? 'Reset your password' : 'MyFinance account'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.phone_iphone_rounded,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Your local data stays on this device',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xSmall),
                            Text(
                              'Signing in creates an optional cloud account. Existing local records will not be merged or uploaded automatically.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  forgot
                      ? 'We’ll email you a secure password reset link.'
                      : signUp
                      ? 'Create an account to enable optional cloud access.'
                      : 'Sign in to your MyFinance account.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                if (!auth.isSupabaseAvailable)
                  const _ConfigurationNotice()
                else ...<Widget>[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: forgot
                              ? TextInputAction.done
                              : TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          validator: validateEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        if (!forgot) ...<Widget>[
                          const SizedBox(height: AppSpacing.medium),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            textInputAction: signUp
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: signUp
                                ? const <String>[AutofillHints.newPassword]
                                : const <String>[AutofillHints.password],
                            validator: signUp
                                ? _validatePassword
                                : (String? value) =>
                                      value == null || value.isEmpty
                                      ? 'Enter your password.'
                                      : null,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (signUp) ...<Widget>[
                            const SizedBox(height: AppSpacing.medium),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_confirmationVisible,
                              validator: (String? value) =>
                                  value != _passwordController.text
                                  ? 'Passwords do not match.'
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _confirmationVisible
                                      ? 'Hide password'
                                      : 'Show password',
                                  onPressed: () => setState(
                                    () => _confirmationVisible =
                                        !_confirmationVisible,
                                  ),
                                  icon: Icon(
                                    _confirmationVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (auth.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    _MessageBanner(message: auth.errorMessage!, isError: true),
                  ],
                  if (auth.notice != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    _MessageBanner(message: auth.notice!),
                  ],
                  const SizedBox(height: AppSpacing.medium),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: auth.isLoading ? null : _submit,
                      icon: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        forgot
                            ? 'Send reset link'
                            : signUp
                            ? 'Create account'
                            : 'Sign in',
                      ),
                    ),
                  ),
                  if (widget.flow == AuthFlow.signIn) ...<Widget>[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.push(RouteNames.forgotPasswordPath),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            context.go(RouteNames.authenticationPath),
                        child: const Text('Create an account'),
                      ),
                    ),
                  ] else if (widget.flow == AuthFlow.signUp)
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            context.go(RouteNames.authenticationPath),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    )
                  else
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            context.go(RouteNames.authenticationPath),
                        child: const Text('Back to sign in'),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.medium),
                OutlinedButton.icon(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await ref
                              .read(authenticationProvider.notifier)
                              .useLocalOnly();
                          if (context.mounted) context.go(RouteNames.homePath);
                        },
                  icon: const Icon(Icons.offline_bolt_outlined),
                  label: const Text('Continue without an account'),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'MyFinance works offline. You can keep using it without registering.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthenticationState auth = ref.watch(authenticationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: <Widget>[
                if (!auth.isPasswordRecovery) ...<Widget>[
                  const Icon(Icons.mark_email_read_outlined, size: 52),
                  const SizedBox(height: AppSpacing.medium),
                  const Text(
                    'Open the password reset link from your email on this device to continue.',
                    textAlign: TextAlign.center,
                  ),
                ] else
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          validator: validatePassword,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          validator: (String? value) =>
                              value != _passwordController.text
                              ? 'Passwords do not match.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                        ),
                        if (auth.errorMessage != null)
                          _MessageBanner(
                            message: auth.errorMessage!,
                            isError: true,
                          ),
                        if (auth.notice != null)
                          _MessageBanner(message: auth.notice!),
                        const SizedBox(height: AppSpacing.medium),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: auth.isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      ref
                                          .read(authenticationProvider.notifier)
                                          .updatePassword(
                                            _passwordController.text,
                                          );
                                    }
                                  },
                            child: const Text('Update password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: () => context.go(RouteNames.authenticationPath),
                  child: const Text('Back to MyFinance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice();

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const Icon(Icons.cloud_off_outlined, size: 44),
      const SizedBox(height: AppSpacing.small),
      const Text(
        'Online sign-in is not configured for this build. Continue in local-only mode; your records remain on this device.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.tertiaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onTertiaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}
