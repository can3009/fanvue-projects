import 'package:admin_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// --- THEME CONSTANTS (Premium Dark) ---
const kBgColorDark = Color(0xFF0F1115);
const kCardColorDark = Color(0xFF1B222F);
const kPrimaryColor = Color(0xFF06B6D4); // Cyan-500
const kSecondaryColor = Color(0xFF6366F1); // Indigo-500
const kSuccessColor = Color(0xFF10B981);
const kDangerColor = Color(0xFFEF4444);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF9CA3AF);

class MassMessagesDialog extends StatefulWidget {
  const MassMessagesDialog({super.key});

  @override
  State<MassMessagesDialog> createState() => _MassMessagesDialogState();
}

class _MassMessagesDialogState extends State<MassMessagesDialog> {
  // Mock Data for UI - Moved to build for localization
  final Set<String> _selectedLists = {};

  final List<String> _templates = [
    "Hey babe! 💖 I've been thinking about you... check out my latest post!",
    "Miss me? 😉 I have a little surprise for you in my DMs...",
    "Happy Weekend! 🎉 sending you some good vibes and a cute pic!",
    "It's so cold today ❄️ want to help me warm up?",
  ];
  String? _selectedTemplate;
  final TextEditingController _messageController = TextEditingController();

  void _generateGrokMessage() {
    // Placeholder for future Grok logic
    setState(() {
      _messageController.text =
          "✨ [Grok Generated]: Hey sticky sweet! I just finished a workout and thought of you. Want to see? 💦";
      _selectedTemplate = null; // Clear manual template selection
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final List<String> lists = [
      strings.allSubs, // 'All Subscribers',
      '${strings.highSpenders} (\$100+)',
      '${strings.newSubscribers} (7d)', // Shortened for UI fit if needed
      '${strings.inactiveSubs} (30d+)',
      strings.vips,
    ];

    return Dialog(
      backgroundColor: kCardColorDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 800, // Large dialog
        height: 700,
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: kTextSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 48),

            // --- Main Content (Split View) ---
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Left: Target Audience ---
                  Expanded(
                    flex: 2,
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
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: kBgColorDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: lists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final listName = lists[index];
                                final isSelected = _selectedLists.contains(
                                  listName,
                                );
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedLists.remove(listName);
                                      } else {
                                        _selectedLists.add(listName);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? kPrimaryColor.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? kPrimaryColor
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: isSelected
                                              ? kPrimaryColor
                                              : kTextSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            listName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? kTextPrimary
                                                  : kTextSecondary,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
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
                        ),
                      ],
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
                                    TextButton.icon(
                                      onPressed: _generateGrokMessage,
                                      icon: const Icon(
                                        Icons.auto_awesome,
                                        color: kSecondaryColor,
                                      ),
                                      label: Text(
                                        strings.generateWithGrok,
                                        style: const TextStyle(
                                          color: kSecondaryColor,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        backgroundColor: kSecondaryColor
                                            .withOpacity(0.1),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(
                                        Icons.image,
                                        color: kTextSecondary,
                                      ),
                                      tooltip: 'Add Image',
                                    ),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(
                                        Icons.emoji_emotions,
                                        color: kTextSecondary,
                                      ),
                                      tooltip: 'Add Emoji',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Templates Selection
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _templates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final template = _templates[index];
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _messageController.text = template;
                                    _selectedTemplate = template;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 200,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: kBgColorDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedTemplate == template
                                          ? kPrimaryColor
                                          : Colors.white10,
                                    ),
                                  ),
                                  child: Text(
                                    template,
                                    style: TextStyle(
                                      color: kTextSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- Footer Actions ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  strings.selectedLists(_selectedLists.length.toString()),
                  style: const TextStyle(color: kTextSecondary),
                ),
                const SizedBox(width: 24),
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
                  onPressed: () {
                    // Logic to send messages will go here
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mass messages queued successfully!'),
                        backgroundColor: kSuccessColor,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send),
                  label: Text(strings.sendMassMessage),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
