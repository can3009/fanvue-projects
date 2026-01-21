import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/creators_controller.dart';
import '../data/models/creator.dart';
import '../l10n/app_localizations.dart';

// --- THEME CONSTANTS (Premium Dark) ---
const kBgColorDark = Color(0xFF0F1115);
const kCardColorDark = Color(0xFF1B222F);
const kPrimaryColor = Color(0xFF06B6D4); // Cyan-500
const kSecondaryColor = Color(0xFF6366F1); // Indigo-500
const kSuccessColor = Color(0xFF10B981);
const kDangerColor = Color(0xFFEF4444);
const kWarningColor = Color(0xFFF59E0B);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF9CA3AF);

class CreatorsScreen extends ConsumerWidget {
  const CreatorsScreen({super.key});

  Future<void> _addCreator(BuildContext context, WidgetRef ref) async {
    final strings = AppLocalizations.of(context);
    final displayNameController = TextEditingController();
    final fanvueIdController = TextEditingController();
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();
    final webhookSecretController = TextEditingController();
    final activeNotifier = ValueNotifier(true);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColorDark,
        title: Text(
          strings.addCreator,
          style: const TextStyle(color: kTextPrimary),
        ),
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
                _buildStyledTextField(
                  controller: displayNameController,
                  label: '${strings.displayName} *',
                ),
                const SizedBox(height: 12),
                _buildStyledTextField(
                  controller: fanvueIdController,
                  label: 'Fanvue Creator ID',
                  hint: 'Optional, auto-generated if empty',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fanvue API Credentials',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStyledTextField(
                  controller: clientIdController,
                  label: 'Client ID *',
                  hint: 'From Fanvue Developer Portal',
                ),
                const SizedBox(height: 12),
                _buildStyledTextField(
                  controller: clientSecretController,
                  label: 'Client Secret *',
                  hint: 'From Fanvue Developer Portal',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                _buildStyledTextField(
                  controller: webhookSecretController,
                  label: 'Webhook Signature Secret *',
                  hint: 'For verifying incoming webhooks',
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                // Webhook URL section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBgColorDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Webhook URL (for Fanvue)',
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              'https://yjtzwolupyhnyfjqjsxu.supabase.co/functions/v1/fanvue-webhook',
                              style: TextStyle(
                                color: kTextSecondary.withOpacity(0.8),
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 18,
                              color: kTextSecondary,
                            ),
                            tooltip: 'Copy URL',
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
                                  content: Text('Webhook URL copied!'),
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
                    activeColor: kSuccessColor,
                    inactiveThumbColor: kTextSecondary,
                    inactiveTrackColor: kBgColorDark,
                    onChanged: (next) => activeNotifier.value = next,
                    title: Text(
                      strings.active,
                      style: const TextStyle(color: kTextPrimary),
                    ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(strings.create),
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
    final strings = AppLocalizations.of(context);

    // Main Scaffold Background
    return Scaffold(
      backgroundColor: kBgColorDark,
      body: state.loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : state.error != null
          ? Center(
              child: Text(
                state.error!,
                style: const TextStyle(color: kDangerColor),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Left Panel: Creator List ---
                  Expanded(
                    flex: 0,
                    child: Container(
                      width: 300,
                      decoration: _cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                const Icon(Icons.group, color: kPrimaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  strings.creators,
                                  style: const TextStyle(
                                    color: kTextPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: ref
                                      .read(creatorsControllerProvider.notifier)
                                      .load,
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: kTextSecondary,
                                  ),
                                  tooltip: strings.refreshData,
                                ),
                                IconButton(
                                  onPressed: () => _addCreator(context, ref),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: kSuccessColor,
                                  ),
                                  tooltip: strings.addCreator,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          Expanded(
                            child: state.creators.isEmpty
                                ? Center(
                                    child: Text(
                                      strings.noCreatorsConfigured,
                                      style: const TextStyle(
                                        color: kTextSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: state.creators.length,
                                    itemBuilder: (context, index) {
                                      final creator = state.creators[index];
                                      final isSelected =
                                          state.selected?.id == creator.id;
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? kPrimaryColor.withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: isSelected
                                              ? Border.all(
                                                  color: kPrimaryColor
                                                      .withOpacity(0.5),
                                                )
                                              : null,
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 4,
                                              ),
                                          title: Text(
                                            creator.displayName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? kPrimaryColor
                                                  : kTextPrimary,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: creator.isActive
                                                      ? kSuccessColor
                                                      : kTextSecondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                creator.isActive
                                                    ? strings.active
                                                    : strings.inactive,
                                                style: TextStyle(
                                                  color: kTextSecondary
                                                      .withOpacity(0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () => ref
                                              .read(
                                                creatorsControllerProvider
                                                    .notifier,
                                              )
                                              .selectCreator(creator),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // --- Right Panel: Creator Details ---
                  Expanded(
                    child: state.selected == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 48,
                                  color: kTextSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  strings.selectCreatorToManage,
                                  style: TextStyle(
                                    color: kTextSecondary.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: _cardDecoration,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: _CreatorDetail(
                                creator: state.selected!,
                                oauthConnected: state.oauthConnected,
                                oauthExpired: state.oauthExpired,
                                hasIntegration: state.hasIntegration,
                                onSave: (settings, isActive) => ref
                                    .read(creatorsControllerProvider.notifier)
                                    .saveSettings(
                                      settings: settings,
                                      isActive: isActive,
                                    ),
                                onStartOAuth: () => _startOAuth(ref),
                                onUpdateIntegration: (clientId, clientSecret) =>
                                    ref
                                        .read(
                                          creatorsControllerProvider.notifier,
                                        )
                                        .updateIntegration(
                                          fanvueClientId: clientId,
                                          fanvueClientSecret: clientSecret,
                                        ),
                                onDelete: () => ref
                                    .read(creatorsControllerProvider.notifier)
                                    .deleteCreator(state.selected!),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CreatorDetail extends StatefulWidget {
  const _CreatorDetail({
    required this.creator,
    required this.oauthConnected,
    required this.oauthExpired,
    required this.hasIntegration,
    required this.onSave,
    required this.onStartOAuth,
    required this.onUpdateIntegration,
    required this.onDelete,
  });

  final Creator creator;
  final bool oauthConnected;
  final bool oauthExpired;
  final bool hasIntegration;
  final Future<void> Function(CreatorSettings settings, bool isActive) onSave;
  final VoidCallback onStartOAuth;
  final Future<void> Function(String clientId, String clientSecret)
  onUpdateIntegration;
  final Future<void> Function() onDelete;

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
    if (oldWidget.creator.id != widget.creator.id ||
        oldWidget.creator.settings != widget.creator.settings ||
        oldWidget.creator.isActive != widget.creator.isActive) {
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
        backgroundColor: kCardColorDark,
        title: const Text(
          'Add Fanvue Credentials',
          style: TextStyle(color: kTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStyledTextField(
              controller: clientIdController,
              label: 'Client ID',
              hint: 'From Fanvue Developer Portal',
            ),
            const SizedBox(height: 12),
            _buildStyledTextField(
              controller: clientSecretController,
              label: 'Client Secret',
              hint: 'From Fanvue Developer Portal',
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
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
    final strings = AppLocalizations.of(context);
    return Column(
      children: [
        // --- Header Section ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kCardColorDark.withLightness(0.05),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: kPrimaryColor.withOpacity(0.2),
                    child: Text(
                      widget.creator.displayName.isNotEmpty
                          ? widget.creator.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: kPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.creator.displayName,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Status Chips
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _StatusChip(
                              label: widget.hasIntegration
                                  ? 'API Connected'
                                  : 'API Missing',
                              color: widget.hasIntegration
                                  ? kSuccessColor
                                  : kWarningColor,
                              isError: !widget.hasIntegration,
                            ),
                            _StatusChip(
                              label: widget.oauthExpired
                                  ? 'OAuth Expired'
                                  : widget.oauthConnected
                                  ? 'OAuth Active'
                                  : 'OAuth Missing',
                              color: widget.oauthExpired
                                  ? kDangerColor
                                  : widget.oauthConnected
                                  ? kSuccessColor
                                  : kWarningColor,
                              isError:
                                  !widget.oauthConnected || widget.oauthExpired,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions List
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!widget.hasIntegration)
                        TextButton.icon(
                          onPressed: () => _showAddCredentialsDialog(context),
                          icon: const Icon(
                            Icons.key,
                            size: 18,
                            color: kPrimaryColor,
                          ),
                          label: const Text(
                            'Add API Keys',
                            style: TextStyle(color: kPrimaryColor),
                          ),
                        ),
                      if (widget.hasIntegration &&
                          (!widget.oauthConnected || widget.oauthExpired))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: widget.onStartOAuth,
                            icon: Icon(
                              widget.oauthExpired ? Icons.refresh : Icons.link,
                              size: 18,
                            ),
                            label: Text(
                              widget.oauthExpired ? 'Reconnect' : 'Connect',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.oauthExpired
                                  ? kDangerColor
                                  : kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: kCardColorDark,
                              title: Text(
                                strings.deleteCreatorTitle,
                                style: const TextStyle(color: kTextPrimary),
                              ),
                              content: Text(
                                strings.deleteCreatorConfirm(
                                  widget.creator.displayName,
                                ),
                                style: const TextStyle(color: kTextSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: kTextSecondary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kDangerColor,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await widget.onDelete();
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: kDangerColor,
                        ),
                        tooltip: 'Delete Creator',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // IDs Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kBgColorDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildIdRow(context, 'DB ID', widget.creator.id),
                    const SizedBox(height: 4),
                    _buildIdRow(
                      context,
                      'Fanvue ID',
                      widget.creator.fanvueCreatorId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- Tabs ---
        Container(
          color: kCardColorDark,
          child: TabBar(
            controller: _tabController,
            labelColor: kPrimaryColor,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimaryColor,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.white10,
            tabs: const [
              Tab(text: 'Basic'),
              Tab(text: 'Personality'),
              Tab(text: 'Behavior'),
              Tab(text: 'Rules'),
            ],
          ),
        ),

        // --- Tab Content ---
        Expanded(
          child: Container(
            color: kCardColorDark,
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContentWrapper(_buildBasicTab()),
                  _buildContentWrapper(_buildPersonalityTab()),
                  _buildContentWrapper(_buildBehaviorTab()),
                  _buildContentWrapper(_buildRulesTab()),
                ],
              ),
            ),
          ),
        ),

        // --- Footer Actions ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kCardColorDark,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: SwitchListTile(
                  value: _active,
                  activeColor: kSuccessColor,
                  inactiveThumbColor: kTextSecondary,
                  inactiveTrackColor: kBgColorDark,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text(
                    'Active Status',
                    style: TextStyle(color: kTextPrimary),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildIdRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 14, color: kTextSecondary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Copy $label',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied!'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBasicTab() {
    return Column(
      children: [
        _buildStyledTextField(
          controller: _nameController,
          label: 'Persona Name',
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _ageController,
          label: 'Age',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _locationController,
          label: 'Location',
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _occupationController,
          label: 'Occupation',
        ),
      ],
    );
  }

  Widget _buildPersonalityTab() {
    return Column(
      children: [
        _buildStyledTextField(
          controller: _traitsController,
          label: 'Personality Traits',
          hint: 'e.g. Shy, Caring, Flirty',
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _speakingStyleController,
          label: 'Speaking Style',
          hint: 'e.g. Gen Z slang, Formal',
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _hobbiesController,
          label: 'Hobbies',
          hint: 'e.g. Gaming, Yoga, Reading',
        ),
        const SizedBox(height: 16),
        _buildStyledTextField(
          controller: _backstoryController,
          label: 'Backstory',
          hint: 'Short bio for the persona...',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildBehaviorTab() {
    return Column(
      children: [
        _buildSlider(
          'Arrogance',
          _arrogance,
          (v) => setState(() => _arrogance = v.round()),
        ),
        _buildSlider(
          'Dominance',
          _dominance,
          (v) => setState(() => _dominance = v.round()),
        ),
        _buildSlider(
          'Flirtiness',
          _flirtiness,
          (v) => setState(() => _flirtiness = v.round()),
        ),
        _buildSlider(
          'Lewdness',
          _lewdness,
          (v) => setState(() => _lewdness = v.round()),
        ),
        _buildSlider(
          'Emoji Usage',
          _emojiUsage,
          (v) => setState(() => _emojiUsage = v.round()),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _replyLength,
          dropdownColor: kCardColorDark,
          style: const TextStyle(color: kTextPrimary),
          decoration: _buildInputDecoration('Reply Length'),
          items: const [
            DropdownMenuItem(value: 'short', child: Text('Short')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'long', child: Text('Long')),
          ],
          onChanged: (value) =>
              setState(() => _replyLength = value ?? 'medium'),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return Column(
      children: [
        _buildStyledTextField(
          controller: _doRulesController,
          label: 'Do Rules (one per line)',
          hint: 'Always reply quickly...\nUse emojis often...',
          maxLines: 6,
        ),
        const SizedBox(height: 24),
        _buildStyledTextField(
          controller: _dontRulesController,
          label: 'Don\'t Rules (one per line)',
          hint: 'Never mention real name...\nDon\'t be rude...',
          maxLines: 6,
        ),
        const SizedBox(height: 24),
        _buildStyledTextField(
          controller: _aiDeflectionController,
          label: 'AI Deflection Responses (one per line)',
          hint: 'I am not an AI, silly!...\nWhy would you ask that?...',
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _buildSlider(String label, int value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: kPrimaryColor,
                inactiveTrackColor: kBgColorDark,
                thumbColor: kPrimaryColor,
                overlayColor: kPrimaryColor.withOpacity(0.2),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: value.toString(),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper Functions & Widgets ---

BoxDecoration get _cardDecoration => BoxDecoration(
  color: kCardColorDark,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: Colors.white.withOpacity(0.05)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

InputDecoration _buildInputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: kTextSecondary),
    hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.5)),
    filled: true,
    fillColor: kBgColorDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

Widget _buildStyledTextField({
  required TextEditingController controller,
  required String label,
  String? hint,
  bool obscureText = false,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return TextFormField(
    controller: controller,
    style: const TextStyle(color: kTextPrimary),
    obscureText: obscureText,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: _buildInputDecoration(label, hint: hint),
    validator: (value) {
      if (label.contains('*') && (value == null || value.trim().isEmpty)) {
        return 'Required';
      }
      return null;
    },
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isError;

  const _StatusChip({
    required this.label,
    required this.color,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color withLightness(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
