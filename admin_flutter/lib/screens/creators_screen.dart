import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/creators_controller.dart';
import '../data/models/creator.dart';
import '../widgets/section_card.dart';

class CreatorsScreen extends ConsumerWidget {
  const CreatorsScreen({super.key});

  Future<void> _addCreator(BuildContext context, WidgetRef ref) async {
    final displayNameController = TextEditingController();
    final fanvueIdController = TextEditingController();
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();
    final webhookSecretController = TextEditingController();
    final activeNotifier = ValueNotifier(true);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add creator'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fanvueIdController,
                  decoration: const InputDecoration(
                    labelText: 'Fanvue creator ID',
                    hintText: 'Optional, auto-generated if empty',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fanvue API Credentials',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Client ID *',
                    hintText: 'From Fanvue Developer Portal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clientSecretController,
                  decoration: const InputDecoration(
                    labelText: 'Client Secret *',
                    hintText: 'From Fanvue Developer Portal',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: webhookSecretController,
                  decoration: const InputDecoration(
                    labelText: 'Webhook Signature Secret *',
                    hintText: 'For verifying incoming webhooks',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                // Webhook URL section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Webhook URL (für Fanvue)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              'https://yjtzwolupyhnyfjqjsxu.supabase.co/functions/v1/fanvue-webhook',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'URL kopieren',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(
                                  text:
                                      'https://yjtzwolupyhnyfjqjsxu.supabase.co/functions/v1/fanvue-webhook',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Webhook URL kopiert!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder(
                  valueListenable: activeNotifier,
                  builder: (context, value, _) => SwitchListTile(
                    value: value,
                    onChanged: (next) => activeNotifier.value = next,
                    title: const Text('Active'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != true) return;
    if (displayNameController.text.trim().isEmpty) return;
    await ref
        .read(creatorsControllerProvider.notifier)
        .addCreator(
          displayName: displayNameController.text.trim(),
          fanvueCreatorId: fanvueIdController.text.trim(),
          isActive: activeNotifier.value,
          fanvueClientId: clientIdController.text.trim(),
          fanvueClientSecret: clientSecretController.text.trim(),
          fanvueWebhookSecret: webhookSecretController.text.trim(),
        );
  }

  Future<void> _startOAuth(WidgetRef ref) async {
    final url = ref.read(creatorsControllerProvider.notifier).buildOAuthUrl();
    if (url.toString().isEmpty) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creatorsControllerProvider);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    return Row(
      children: [
        Expanded(
          flex: 0,
          child: SizedBox(
            width: 280,
            child: SectionCard(
            title: 'Creators',
            expand: true,
            actions: [
              IconButton(
                onPressed: ref.read(creatorsControllerProvider.notifier).load,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                onPressed: () => _addCreator(context, ref),
                icon: const Icon(Icons.add),
              ),
            ],
            child: state.creators.isEmpty
                ? const Text('No creators yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.creators.length,
                    itemBuilder: (context, index) {
                      final creator = state.creators[index];
                      return ListTile(
                        title: Text(creator.displayName),
                        subtitle: Text(
                          creator.isActive ? 'Active' : 'Inactive',
                        ),
                        selected: state.selected?.id == creator.id,
                        onTap: () => ref
                            .read(creatorsControllerProvider.notifier)
                            .selectCreator(creator),
                      );
                    },
                  ),
          ),
          ),
        ),
        Expanded(
          child: state.selected == null
              ? const Center(child: Text('Select a creator'))
              : _CreatorDetail(
                  creator: state.selected!,
                  oauthConnected: state.oauthConnected,
                  hasIntegration: state.hasIntegration,
                  onSave: (settings, isActive) => ref
                      .read(creatorsControllerProvider.notifier)
                      .saveSettings(settings: settings, isActive: isActive),
                  onStartOAuth: () => _startOAuth(ref),
                  onUpdateIntegration: (clientId, clientSecret) => ref
                      .read(creatorsControllerProvider.notifier)
                      .updateIntegration(
                        fanvueClientId: clientId,
                        fanvueClientSecret: clientSecret,
                      ),
                ),
        ),
      ],
    );
  }
}

class _CreatorDetail extends StatefulWidget {
  const _CreatorDetail({
    required this.creator,
    required this.oauthConnected,
    required this.hasIntegration,
    required this.onSave,
    required this.onStartOAuth,
    required this.onUpdateIntegration,
  });

  final Creator creator;
  final bool oauthConnected;
  final bool hasIntegration;
  final Future<void> Function(CreatorSettings settings, bool isActive) onSave;
  final VoidCallback onStartOAuth;
  final Future<void> Function(String clientId, String clientSecret)
  onUpdateIntegration;

  @override
  State<_CreatorDetail> createState() => _CreatorDetailState();
}

class _CreatorDetailState extends State<_CreatorDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // General
  bool _active = true;

  // Basic Info
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _occupationController = TextEditingController();

  // Personality
  final _traitsController = TextEditingController();
  final _speakingStyleController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _backstoryController = TextEditingController();

  // Behavior sliders
  int _arrogance = 0;
  int _dominance = 0;
  int _flirtiness = 5;
  int _lewdness = 5;
  int _emojiUsage = 5;
  String _replyLength = 'medium';

  // Rules
  final _doRulesController = TextEditingController();
  final _dontRulesController = TextEditingController();
  final _aiDeflectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _hydrate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _traitsController.dispose();
    _speakingStyleController.dispose();
    _hobbiesController.dispose();
    _backstoryController.dispose();
    _doRulesController.dispose();
    _dontRulesController.dispose();
    _aiDeflectionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CreatorDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creator.id != widget.creator.id) {
      _hydrate();
    }
  }

  void _hydrate() {
    final s = widget.creator.settings;
    _active = widget.creator.isActive;

    _nameController.text = s.name ?? '';
    _ageController.text = s.age?.toString() ?? '';
    _locationController.text = s.location ?? '';
    _occupationController.text = s.occupation ?? '';

    _traitsController.text = s.personalityTraits.join(', ');
    _speakingStyleController.text = s.speakingStyle ?? '';
    _hobbiesController.text = s.hobbies.join(', ');
    _backstoryController.text = s.backstory ?? '';

    _arrogance = s.arrogance;
    _dominance = s.dominance;
    _flirtiness = s.flirtiness;
    _lewdness = s.lewdness;
    _emojiUsage = s.emojiUsage;
    _replyLength = s.replyLength;

    _doRulesController.text = s.doRules.join('\n');
    _dontRulesController.text = s.dontRules.join('\n');
    _aiDeflectionController.text = s.aiDeflectionResponses.join('\n');
  }

  List<String> _parseLines(String text) {
    return text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _parseCommaList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = CreatorSettings(
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      age: int.tryParse(_ageController.text),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      personalityTraits: _parseCommaList(_traitsController.text),
      speakingStyle: _speakingStyleController.text.trim().isEmpty
          ? null
          : _speakingStyleController.text.trim(),
      hobbies: _parseCommaList(_hobbiesController.text),
      backstory: _backstoryController.text.trim().isEmpty
          ? null
          : _backstoryController.text.trim(),
      doRules: _parseLines(_doRulesController.text),
      dontRules: _parseLines(_dontRulesController.text),
      flirtiness: _flirtiness,
      lewdness: _lewdness,
      emojiUsage: _emojiUsage,
      arrogance: _arrogance,
      dominance: _dominance,
      replyLength: _replyLength,
      aiDeflectionResponses: _parseLines(_aiDeflectionController.text),
    );

    await widget.onSave(settings, _active);
  }

  Future<void> _showAddCredentialsDialog(BuildContext context) async {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Fanvue Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                hintText: 'From Fanvue Developer Portal',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientSecretController,
              decoration: const InputDecoration(
                labelText: 'Client Secret',
                hintText: 'From Fanvue Developer Portal',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true &&
        clientIdController.text.isNotEmpty &&
        clientSecretController.text.isNotEmpty) {
      await widget.onUpdateIntegration(
        clientIdController.text.trim(),
        clientSecretController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: widget.creator.displayName,
      expand: true,
      actions: [
        // Integration status
        Chip(
          label: Text(widget.hasIntegration ? 'API ✓' : 'API missing'),
          backgroundColor: widget.hasIntegration
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
        ),
        const SizedBox(width: 4),
        // OAuth status
        Chip(
          label: Text(widget.oauthConnected ? 'OAuth ✓' : 'OAuth missing'),
          backgroundColor: widget.oauthConnected
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
        ),
        const SizedBox(width: 8),
        // Action buttons
        if (!widget.hasIntegration)
          TextButton.icon(
            onPressed: () => _showAddCredentialsDialog(context),
            icon: const Icon(Icons.key, size: 18),
            label: const Text('Add Credentials'),
          ),
        if (widget.hasIntegration && !widget.oauthConnected)
          ElevatedButton(
            onPressed: widget.onStartOAuth,
            child: const Text('Connect OAuth'),
          ),
      ],
      child: Column(
        children: [
          // Active toggle at the top
          SwitchListTile(
            value: _active,
            onChanged: (value) => setState(() => _active = value),
            title: const Text('Active'),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
            tabs: const [
              Tab(text: 'Basic'),
              Tab(text: 'Personality'),
              Tab(text: 'Behavior'),
              Tab(text: 'Rules'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicTab(),
                  _buildPersonalityTab(),
                  _buildBehaviorTab(),
                  _buildRulesTab(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Save settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Persona Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(labelText: 'Age'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _occupationController,
            decoration: const InputDecoration(labelText: 'Occupation'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _traitsController,
            decoration: const InputDecoration(
              labelText: 'Personality Traits',
              hintText: 'e.g. Shy, Caring, Flirty',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _speakingStyleController,
            decoration: const InputDecoration(
              labelText: 'Speaking Style',
              hintText: 'e.g. Gen Z slang, Formal',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hobbiesController,
            decoration: const InputDecoration(
              labelText: 'Hobbies',
              hintText: 'e.g. Gaming, Yoga, Reading',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _backstoryController,
            decoration: const InputDecoration(
              labelText: 'Backstory',
              hintText: 'Short bio for the persona...',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSlider('Arrogance', _arrogance, (v) {
            setState(() => _arrogance = v.round());
          }),
          _buildSlider('Dominance', _dominance, (v) {
            setState(() => _dominance = v.round());
          }),
          _buildSlider('Flirtiness', _flirtiness, (v) {
            setState(() => _flirtiness = v.round());
          }),
          _buildSlider('Lewdness', _lewdness, (v) {
            setState(() => _lewdness = v.round());
          }),
          _buildSlider('Emoji Usage', _emojiUsage, (v) {
            setState(() => _emojiUsage = v.round());
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _replyLength,
            decoration: const InputDecoration(labelText: 'Reply Length'),
            items: const [
              DropdownMenuItem(value: 'short', child: Text('Short')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'long', child: Text('Long')),
            ],
            onChanged: (value) =>
                setState(() => _replyLength = value ?? 'medium'),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, int value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: value.toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 30, child: Text(value.toString())),
      ],
    );
  }

  Widget _buildRulesTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _doRulesController,
            decoration: const InputDecoration(
              labelText: 'DO Rules (one per line)',
              hintText: 'Always mention cats when asked about pets',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dontRulesController,
            decoration: const InputDecoration(
              labelText: "DON'T Rules (one per line)",
              hintText: 'Never discuss politics',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _aiDeflectionController,
            decoration: const InputDecoration(
              labelText: 'AI Deflection Responses (one per line)',
              hintText: 'lol what do you think?',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
