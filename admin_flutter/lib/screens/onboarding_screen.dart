import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/onboarding_state.dart';
import '../logic/onboarding_notifier.dart';

/// Main Onboarding Screen with Stepper/Wizard UI
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingNotifierProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Onboarding'),
        leading: state.canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref
                    .read(onboardingNotifierProvider.notifier)
                    .previousStep(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${state.stepIndex + 1}/${state.totalSteps}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: theme.colorScheme.surface,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.error.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => ref
                        .read(onboardingNotifierProvider.notifier)
                        .clearError(),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                state.isLoading &&
                    state.currentStep != OnboardingStep.testConnection
                ? const Center(child: CircularProgressIndicator())
                : _buildStepContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(OnboardingState state) {
    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return const _WelcomeStep();
      case OnboardingStep.creatorProfile:
        return const _CreatorProfileStep();
      case OnboardingStep.fanvueCredentials:
        return const _FanvueCredentialsStep();
      case OnboardingStep.oauthConnect:
        return const _OAuthConnectStep();
      case OnboardingStep.webhookSetup:
        return const _WebhookSetupStep();
      case OnboardingStep.testConnection:
        return const _TestConnectionStep();
      case OnboardingStep.done:
        return const _DoneStep();
    }
  }
}

// ============================================
// STEP 1: Welcome
// ============================================

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.waving_hand, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Welcome to Creator Onboarding',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This wizard will connect your Fanvue account to the chatbot system. '
            'You\'ll need access to your Fanvue Developer Portal.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _InfoCard(
            icon: Icons.checklist,
            title: 'What you\'ll need:',
            items: const [
              'Your Fanvue Developer account',
              'A Fanvue App with OAuth credentials',
              'The Webhook Signing Secret from Fanvue',
            ],
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.security,
            title: 'Security:',
            items: const [
              'Credentials are stored securely on the server',
              'Nothing sensitive is saved on this device',
              'This app NEVER reads your secrets back',
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  ref.read(onboardingNotifierProvider.notifier).nextStep(),
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// STEP 2: Creator Profile
// ============================================

class _CreatorProfileStep extends ConsumerStatefulWidget {
  const _CreatorProfileStep();

  @override
  ConsumerState<_CreatorProfileStep> createState() =>
      _CreatorProfileStepState();
}

class _CreatorProfileStepState extends ConsumerState<_CreatorProfileStep> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _fanvueIdController = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _fanvueIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator Profile',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your creator details.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g., My Creator Account',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fanvueIdController,
              decoration: const InputDecoration(
                labelText: 'Fanvue Creator ID (optional)',
                hintText: 'Your Fanvue username or ID',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable bot responses'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(onboardingNotifierProvider.notifier)
        .saveCreatorProfile(
          CreatorProfileData(
            displayName: _displayNameController.text.trim(),
            fanvueCreatorId: _fanvueIdController.text.trim().isEmpty
                ? null
                : _fanvueIdController.text.trim(),
            isActive: _isActive,
          ),
        );
  }
}

// ============================================
// STEP 3: Fanvue Credentials (ALL 3 secrets)
// ============================================

class _FanvueCredentialsStep extends ConsumerStatefulWidget {
  const _FanvueCredentialsStep();

  @override
  ConsumerState<_FanvueCredentialsStep> createState() =>
      _FanvueCredentialsStepState();
}

class _FanvueCredentialsStepState
    extends ConsumerState<_FanvueCredentialsStep> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  bool _obscureClientSecret = true;
  bool _obscureWebhookSecret = true;

  final List<String> _allScopes = const [
    'read:chat',
    'write:chat',
    'read:fan',
    'read:creator',
    'read:self',
    'read:media',
    'write:media',
    'read:post',
    'write:post',
    'read:insights',
    'write:creator',
  ];

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _webhookSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fanvue App Credentials',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter credentials from your Fanvue Developer Portal.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Redirect URL (read-only, copy)
            _CopyField(
              label: 'Redirect URL (paste in Fanvue)',
              value: notifier.callbackUrl,
            ),
            const SizedBox(height: 20),

            // Client ID
            TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                prefixIcon: Icon(Icons.key),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Client Secret
            TextFormField(
              controller: _clientSecretController,
              obscureText: _obscureClientSecret,
              decoration: InputDecoration(
                labelText: 'Client Secret',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureClientSecret
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _obscureClientSecret = !_obscureClientSecret,
                  ),
                ),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Webhook Signing Secret
            TextFormField(
              controller: _webhookSecretController,
              obscureText: _obscureWebhookSecret,
              decoration: InputDecoration(
                labelText: 'Webhook Signing Secret',
                helperText: 'From Fanvue App → Webhooks tab',
                prefixIcon: const Icon(Icons.security),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureWebhookSecret
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _obscureWebhookSecret = !_obscureWebhookSecret,
                  ),
                ),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Scopes
            Text(
              'Required Scopes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable these in your Fanvue App:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allScopes.map((scope) {
                return Chip(
                  label: Text(scope, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save & Start OAuth'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(onboardingNotifierProvider.notifier)
        .saveCredentialsAndStartOAuth(
          FanvueCredentialsData(
            fanvueClientId: _clientIdController.text.trim(),
            fanvueClientSecret: _clientSecretController.text.trim(),
            fanvueWebhookSecret: _webhookSecretController.text.trim(),
            scopes: _allScopes,
          ),
        );
  }
}

// ============================================
// STEP 4: OAuth Connect
// ============================================

class _OAuthConnectStep extends ConsumerWidget {
  const _OAuthConnectStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect Fanvue',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click the button below to authorize with Fanvue. After approval, come back here.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = state.oauthStartResponse?.authorizeUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Fanvue Authorization'),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'After Authorization',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('1. Log in to Fanvue if prompted'),
                const SizedBox(height: 4),
                const Text('2. Review and approve the permissions'),
                const SizedBox(height: 4),
                const Text('3. Wait for redirect (may take a moment)'),
                const SizedBox(height: 4),
                const Text('4. Click "Check Connection" below'),
              ],
            ),
          ),
          const SizedBox(height: 40),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.previousStep(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => notifier.checkConnection(),
                  child: const Text('Check Connection'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// STEP 5: Webhook Setup
// ============================================

class _WebhookSetupStep extends ConsumerWidget {
  const _WebhookSetupStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure Webhook',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copy this URL to your Fanvue App\'s Webhook settings.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Webhook URL
          _CopyField(
            label: 'Webhook Endpoint URL',
            value: state.webhookSetup?.webhookUrl ?? notifier.webhookUrl,
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The Webhook Secret you entered earlier is already stored securely.',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _InfoCard(
            icon: Icons.settings,
            title: 'In Fanvue Dev Portal:',
            items: const [
              '1. Go to your App → Webhooks tab',
              '2. Paste the Webhook URL above',
              '3. Enable "message.received" event',
              '4. Enable "transaction.created" event (optional)',
              '5. Save changes',
            ],
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => notifier.confirmWebhookSetup(),
              child: const Text('I\'ve Configured the Webhook'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// STEP 6: Test Connection
// ============================================

class _TestConnectionStep extends ConsumerStatefulWidget {
  const _TestConnectionStep();

  @override
  ConsumerState<_TestConnectionStep> createState() =>
      _TestConnectionStepState();
}

class _TestConnectionStepState extends ConsumerState<_TestConnectionStep> {
  WebhookTestResult? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingNotifierProvider.notifier).checkHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final health = state.connectionHealth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Connection',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify everything is working correctly.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          if (health != null) ...[
            _HealthIndicator(
              label: 'OAuth Token',
              isHealthy: health.tokenPresent && !health.tokenExpired,
              details: health.tokenPresent
                  ? (health.tokenExpired ? 'Expired' : 'Valid')
                  : 'Not found',
            ),
            const SizedBox(height: 12),
            _HealthIndicator(
              label: 'Integration',
              isHealthy: health.integrationExists,
              details: health.integrationExists ? 'Configured' : 'Missing',
            ),
            const SizedBox(height: 12),
            _HealthIndicator(
              label: 'Last Webhook',
              isHealthy: health.lastWebhookAt != null,
              details: health.lastWebhookAt?.toString() ?? 'Never received',
            ),
            if (health.lastWebhookError != null) ...[
              const SizedBox(height: 12),
              _HealthIndicator(
                label: 'Last Error',
                isHealthy: false,
                details: health.lastWebhookError!,
              ),
            ],
          ],
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _runTest,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_testing ? 'Testing...' : 'Send Test Webhook'),
            ),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _testResult!.success
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _testResult!.success ? Icons.check_circle : Icons.error,
                        color: _testResult!.success ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _testResult!.success ? 'Test Passed!' : 'Test Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _testResult!.success
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (!_testResult!.success && _testResult!.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _testResult!.error!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          TextButton.icon(
            onPressed: () => notifier.checkHealth(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Status'),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => notifier.completeOnboarding(),
              child: const Text('Complete Setup'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() => _testing = true);
    try {
      final result = await ref
          .read(onboardingNotifierProvider.notifier)
          .testWebhook();
      setState(() {
        _testResult = result;
        _testing = false;
      });
      // Refresh health after test
      ref.read(onboardingNotifierProvider.notifier).checkHealth();
    } catch (e) {
      setState(() {
        _testResult = WebhookTestResult(
          success: false,
          status: 0,
          signatureValid: false,
          webhookUrl: '',
          testedAt: DateTime.now(),
          error: e.toString(),
        );
        _testing = false;
      });
    }
  }
}

// ============================================
// STEP 7: Done
// ============================================

class _DoneStep extends ConsumerWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Setup Complete!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Fanvue account is now connected.\nIncoming messages will be processed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// HELPER WIDGETS
// ============================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Text('• $item', style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;

  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  final String label;
  final bool isHealthy;
  final String details;

  const _HealthIndicator({
    required this.label,
    required this.isHealthy,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          isHealthy ? Icons.check_circle : Icons.error,
          color: isHealthy ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                details,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
