import 'package:admin_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/broadcast_repository.dart';
import '../logic/creators_controller.dart';

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

class MassMessagesDialog extends ConsumerStatefulWidget {
  const MassMessagesDialog({super.key});

  @override
  ConsumerState<MassMessagesDialog> createState() => _MassMessagesDialogState();
}

class _MassMessagesDialogState extends ConsumerState<MassMessagesDialog> {
  String? _selectedCreatorId;
  final Set<String> _selectedTargetLists = {};
  final Set<String> _selectedExcludeLists = {};
  final TextEditingController _messageController = TextEditingController();

  String _selectedStyle = 'tease';
  bool _isGenerating = false;
  bool _isSending = false;

  List<AudienceList> _audienceLists = [];
  bool _isLoadingLists = false;

  final List<_StyleOption> _styleOptions = const [
    _StyleOption(id: 'tease', label: 'Tease', icon: Icons.local_fire_department),
    _StyleOption(id: 'ppv', label: 'PPV', icon: Icons.attach_money),
    _StyleOption(id: 're-engage', label: 'Re-Engage', icon: Icons.favorite),
    _StyleOption(id: 'promo', label: 'Promo', icon: Icons.campaign),
    _StyleOption(id: 'morning', label: 'Morgen', icon: Icons.wb_sunny),
    _StyleOption(id: 'night', label: 'Nacht', icon: Icons.nightlight),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAudienceLists() async {
    if (_selectedCreatorId == null) return;

    setState(() => _isLoadingLists = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);
      final lists = await repo.getAudienceLists(_selectedCreatorId!);
      setState(() {
        _audienceLists = lists;
        _isLoadingLists = false;
      });
    } catch (e) {
      setState(() => _isLoadingLists = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Listen: $e'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  Future<void> _generateMessage() async {
    if (_selectedCreatorId == null) return;

    setState(() => _isGenerating = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);
      final message = await repo.generateBroadcastMessage(
        creatorId: _selectedCreatorId!,
        style: _selectedStyle,
        topic: '',
      );
      setState(() {
        _messageController.text = message;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren: $e'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  Future<void> _sendBroadcast() async {
    if (_selectedCreatorId == null) return;
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib eine Nachricht ein'),
          backgroundColor: kWarningColor,
        ),
      );
      return;
    }
    if (_selectedTargetLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle mindestens eine Zielgruppe'),
          backgroundColor: kWarningColor,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);

      // Get types for selected lists
      final targetTypes = _selectedTargetLists.map((id) {
        final list = _audienceLists.where((l) => l.id == id).firstOrNull;
        return list?.type ?? 'smart';
      }).toList();

      final excludeTypes = _selectedExcludeLists.map((id) {
        final list = _audienceLists.where((l) => l.id == id).firstOrNull;
        return list?.type ?? 'smart';
      }).toList();

      final result = await repo.sendBroadcast(
        creatorId: _selectedCreatorId!,
        targetAudienceIds: _selectedTargetLists.toList(),
        targetAudienceTypes: targetTypes,
        excludeAudienceIds: _selectedExcludeLists.toList(),
        excludeAudienceTypes: excludeTypes,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Broadcast gesendet! ${result['sent']} erfolgreich, ${result['failed']} fehlgeschlagen',
            ),
            backgroundColor: kSuccessColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Senden: $e'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  Widget _buildCreatorSelectorBar() {
    final state = ref.watch(creatorsControllerProvider);
    final creators = state.creators;

    // Auto-select first creator if none selected
    if (_selectedCreatorId == null && creators.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedCreatorId = creators.first.id;
        });
        _loadAudienceLists();
      });
    }

    final selectedCreator =
        creators.where((c) => c.id == _selectedCreatorId).firstOrNull;

    if (state.loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kBgColorDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const SizedBox(
          width: 100,
          height: 20,
          child: LinearProgressIndicator(color: kPrimaryColor),
        ),
      );
    }

    if (creators.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: kBgColorDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDangerColor.withOpacity(0.3)),
        ),
        child: const Text(
          'Keine Creators',
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Creator wählen',
      onSelected: (creatorId) {
        setState(() {
          _selectedCreatorId = creatorId;
          _selectedTargetLists.clear();
          _selectedExcludeLists.clear();
        });
        _loadAudienceLists();
      },
      offset: const Offset(0, 45),
      color: kCardColorDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => creators
          .map((creator) {
            final isSelected = creator.id == _selectedCreatorId;
            return PopupMenuItem<String>(
              value: creator.id,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kPrimaryColor.withOpacity(0.2),
                    backgroundImage: creator.avatarUrl != null
                        ? NetworkImage(creator.avatarUrl!)
                        : null,
                    child: creator.avatarUrl == null
                        ? Text(
                            creator.displayName.isNotEmpty
                                ? creator.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      creator.displayName,
                      style: TextStyle(
                        color: isSelected ? kPrimaryColor : kTextPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, color: kPrimaryColor, size: 18),
                ],
              ),
            );
          })
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kBgColorDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCreator != null) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: kPrimaryColor.withOpacity(0.2),
                backgroundImage: selectedCreator.avatarUrl != null
                    ? NetworkImage(selectedCreator.avatarUrl!)
                    : null,
                child: selectedCreator.avatarUrl == null
                    ? Text(
                        selectedCreator.displayName.isNotEmpty
                            ? selectedCreator.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  selectedCreator.displayName,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Text(
                'Creator wählen',
                style: TextStyle(color: kTextSecondary, fontSize: 14),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceList({
    required String title,
    required Set<String> selectedIds,
    required void Function(String) onToggle,
    required bool isExclude,
  }) {
    // Separate smart and custom lists
    final smartLists = _audienceLists.where((l) => l.type == 'smart').toList();
    final customLists = _audienceLists.where((l) => l.type == 'custom').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isExclude ? Icons.block : Icons.people,
              color: isExclude ? kDangerColor : kPrimaryColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isExclude ? kDangerColor : kPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingLists)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          )
        else if (_audienceLists.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Keine Listen verfügbar',
                style: TextStyle(color: kTextSecondary.withOpacity(0.5)),
              ),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: kBgColorDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab Bar (Smart / Benutzerdefiniert)
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kCardColorDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: isExclude
                            ? kDangerColor.withOpacity(0.2)
                            : kPrimaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: isExclude ? kDangerColor : kPrimaryColor,
                      unselectedLabelColor: kTextSecondary,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Smart (${smartLists.length})'),
                        Tab(text: 'Benutzerdefiniert (${customLists.length})'),
                      ],
                    ),
                  ),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Smart Lists Tab
                        _buildListView(smartLists, selectedIds, onToggle, isExclude),
                        // Custom Lists Tab
                        _buildListView(customLists, selectedIds, onToggle, isExclude),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView(
    List<AudienceList> lists,
    Set<String> selectedIds,
    void Function(String) onToggle,
    bool isExclude,
  ) {
    if (lists.isEmpty) {
      return Center(
        child: Text(
          'Keine Listen',
          style: TextStyle(color: kTextSecondary.withOpacity(0.5)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        final isSelected = selectedIds.contains(list.id);
        return InkWell(
          onTap: () => onToggle(list.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isExclude
                      ? kDangerColor.withOpacity(0.1)
                      : kPrimaryColor.withOpacity(0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? (isExclude ? kDangerColor : kPrimaryColor)
                      : kTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    list.name,
                    style: TextStyle(
                      color: isSelected ? kTextPrimary : kTextSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kCardColorDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${list.fanCount} Mitglieder',
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.style, color: kSecondaryColor, size: 18),
            SizedBox(width: 8),
            Text(
              'Nachrichten-Stil',
              style: TextStyle(
                color: kSecondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _styleOptions.map((option) {
            final isSelected = _selectedStyle == option.id;
            return InkWell(
              onTap: () => setState(() => _selectedStyle = option.id),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kSecondaryColor.withOpacity(0.2)
                      : kBgColorDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? kSecondaryColor
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option.icon,
                      size: 16,
                      color: isSelected ? kSecondaryColor : kTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? kSecondaryColor : kTextSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    final repo = ref.read(broadcastRepositoryProvider);
    final suggestions = repo.getBroadcastSuggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: kWarningColor, size: 18),
            SizedBox(width: 8),
            Text(
              'Vorschläge',
              style: TextStyle(
                color: kWarningColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    _messageController.text = suggestion.content;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBgColorDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.title,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          suggestion.content,
                          style: TextStyle(
                            color: kTextSecondary.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    // Calculate total recipients
    int totalRecipients = 0;
    for (final listId in _selectedTargetLists) {
      final list = _audienceLists.where((l) => l.id == listId).firstOrNull;
      if (list != null) totalRecipients += list.fanCount;
    }

    return Dialog(
      backgroundColor: kCardColorDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 900,
        height: 750,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: kSecondaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.massMessagesTitle,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      strings.massMessagesDesc,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _buildCreatorSelectorBar(),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: kTextSecondary),
                  tooltip: 'Schließen',
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 32),

            // --- Main Content ---
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Left: Audience Selection ---
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. ${strings.selectAudience}',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAudienceList(
                            title: 'Zielgruppen',
                            selectedIds: _selectedTargetLists,
                            onToggle: (id) {
                              setState(() {
                                if (_selectedTargetLists.contains(id)) {
                                  _selectedTargetLists.remove(id);
                                } else {
                                  _selectedTargetLists.add(id);
                                }
                              });
                            },
                            isExclude: false,
                          ),
                          const SizedBox(height: 24),
                          _buildAudienceList(
                            title: 'Ausschließen',
                            selectedIds: _selectedExcludeLists,
                            onToggle: (id) {
                              setState(() {
                                if (_selectedExcludeLists.contains(id)) {
                                  _selectedExcludeLists.remove(id);
                                } else {
                                  _selectedExcludeLists.add(id);
                                }
                              });
                            },
                            isExclude: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // --- Right: Message Content ---
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. ${strings.writeMessage}',
                          style: const TextStyle(
                            color: kPrimaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Style Selector
                        _buildStyleSelector(),
                        const SizedBox(height: 16),

                        // Message Input
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kBgColorDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    maxLines: null,
                                    style: const TextStyle(
                                      color: kTextPrimary,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: strings.typeAMessage,
                                      hintStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const Divider(color: Colors.white10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _isGenerating ? null : _generateMessage,
                                        icon: _isGenerating
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: kSecondaryColor,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.auto_awesome,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isGenerating
                                              ? 'Generiere...'
                                              : strings.generateWithGrok,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              kSecondaryColor.withOpacity(0.2),
                                          foregroundColor: kSecondaryColor,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Suggestions
                        _buildSuggestions(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Footer Actions ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stats
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people,
                            size: 16,
                            color: kPrimaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '~$totalRecipients Empfänger',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedTargetLists.length} Zielgruppe(n), ${_selectedExcludeLists.length} Ausschlüsse',
                      style: const TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                  ],
                ),

                // Buttons
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextSecondary,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: Text(strings.cancel),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBroadcast,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        elevation: 0,
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        _isSending ? 'Sende...' : strings.sendMassMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleOption {
  const _StyleOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}
