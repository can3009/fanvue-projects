import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/fans_controller.dart';
import '../data/models/fan.dart';
import '../data/models/message.dart';
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

class FansScreen extends ConsumerWidget {
  const FansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fansControllerProvider);
    final strings = AppLocalizations.of(context);

    // Helper decoration for cards
    final cardDecoration = BoxDecoration(
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

    if (state.loading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }
    if (state.error != null) {
      return Center(
        child: Text(state.error!, style: const TextStyle(color: kDangerColor)),
      );
    }

    return Scaffold(
      // Ensure background color is applied
      backgroundColor: kBgColorDark,
      body: Column(
        children: [
          // --- Top Bar: Creator Selector ---
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: kCardColorDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<dynamic>(
                        value: state.selectedCreator,
                        dropdownColor: kCardColorDark,
                        style: const TextStyle(color: kTextPrimary),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: kTextSecondary,
                        ),
                        hint: Text(
                          strings.selectCreator,
                          style: const TextStyle(color: kTextSecondary),
                        ),
                        items: state.creators
                            .map(
                              (creator) => DropdownMenuItem(
                                value: creator,
                                child: Text(creator.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          await ref
                              .read(fansControllerProvider.notifier)
                              .loadFans(value);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: kCardColorDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: IconButton(
                    onPressed: () => ref
                        .read(fansControllerProvider.notifier)
                        .loadCreators(),
                    icon: const Icon(Icons.refresh, color: kTextSecondary),
                    tooltip: strings.refreshCreators,
                  ),
                ),
              ],
            ),
          ),

          // --- Main Content: Split View ---
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Left Panel: Fans List ---
                Container(
                  width: 320,
                  margin: const EdgeInsets.only(
                    left: 24,
                    bottom: 24,
                    right: 12,
                  ),
                  decoration: cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: kPrimaryColor),
                            const SizedBox(width: 8),
                            Text(
                              strings.fans,
                              style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      Expanded(
                        child: state.fans.isEmpty
                            ? Center(
                                child: Text(
                                  strings.noFansFound,
                                  style: const TextStyle(color: kTextSecondary),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: state.fans.length,
                                itemBuilder: (context, index) {
                                  final fan = state.fans[index];
                                  final name = fan.displayName.isNotEmpty
                                      ? fan.displayName
                                      : fan.username;
                                  final isSelected =
                                      state.selectedFan?.id == fan.id;

                                  // Time formatting
                                  String timeString = '';
                                  String sinceContact = '';
                                  if (fan.lastMessageAt != null) {
                                    final time = fan.lastMessageAt!;
                                    timeString =
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                                    final now = DateTime.now();
                                    final difference = now.difference(time);
                                    if (difference.inDays > 0) {
                                      sinceContact =
                                          '${difference.inDays}d ago';
                                    } else if (difference.inHours > 0) {
                                      sinceContact =
                                          '${difference.inHours}h ago';
                                    } else if (difference.inMinutes > 0) {
                                      sinceContact =
                                          '${difference.inMinutes}m ago';
                                    } else {
                                      sinceContact = 'Just now';
                                    }
                                  }

                                  // Generate avatar color
                                  final avatarColor = Color(
                                    (name.hashCode & 0xFFFFFF) | 0xFF000000,
                                  ).withOpacity(1.0);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? kPrimaryColor.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: kPrimaryColor.withOpacity(
                                                0.5,
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor: avatarColor,
                                        radius: 20,
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 14,
                                                color: isSelected
                                                    ? kPrimaryColor
                                                    : kTextPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (timeString.isNotEmpty)
                                            Text(
                                              timeString,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: kTextSecondary
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: sinceContact.isNotEmpty
                                          ? Text(
                                              sinceContact,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: kTextSecondary
                                                    .withOpacity(0.6),
                                              ),
                                            )
                                          : null,
                                      selected: isSelected,
                                      onTap: () async {
                                        await ref
                                            .read(
                                              fansControllerProvider.notifier,
                                            )
                                            .loadMessages(fan);
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // --- Right Panel: Chat Area ---
                Expanded(
                  child: state.selectedFan == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: kTextSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                strings.selectFanToView,
                                style: TextStyle(
                                  color: kTextSecondary.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(
                            right: 24,
                            bottom: 24,
                            left: 12,
                          ),
                          decoration: cardDecoration,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _ChatPanel(
                              fan: state.selectedFan!,
                              messages: state.messages,
                              onSend: (message) => ref
                                  .read(fansControllerProvider.notifier)
                                  .enqueueReply(message),
                              onRefresh: () async {
                                final fan = state.selectedFan;
                                if (fan != null) {
                                  await ref
                                      .read(fansControllerProvider.notifier)
                                      .loadMessages(fan);
                                }
                              },
                              onDelete: () async {
                                final fan = state.selectedFan;
                                if (fan != null) {
                                  await ref
                                      .read(fansControllerProvider.notifier)
                                      .deleteFan(fan);
                                }
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({
    required this.fan,
    required this.messages,
    required this.onSend,
    required this.onRefresh,
    required this.onDelete,
  });

  final Fan fan;
  final List<ChatMessage> messages;
  final Future<void> Function(String message) onSend;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDelete;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await widget.onSend(_controller.text.trim());
    _controller.clear();
    await widget.onRefresh();
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      children: [
        // --- Chat Header ---
        _FanDetailsHeader(
          fan: widget.fan,
          onRefresh: widget.onRefresh,
          onDelete: widget.onDelete,
        ),
        const Divider(height: 1, color: Colors.white10),

        // --- Messages List ---
        Expanded(
          child: Container(
            color: kBgColorDark.withOpacity(0.3), // Slightly darker chat bg
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isOutbound = message.direction == 'outbound';
                String timeString = '';
                if (message.createdAt != null) {
                  final time = message.createdAt!;
                  timeString =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                }
                return Align(
                  alignment: isOutbound
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: isOutbound
                          ? kPrimaryColor.withOpacity(0.15)
                          : kCardColorDark,
                      border: Border.all(
                        color: isOutbound
                            ? kPrimaryColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isOutbound
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomRight: isOutbound
                            ? Radius.zero
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isOutbound
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: kTextPrimary,
                            height: 1.4,
                          ),
                        ),
                        if (timeString.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 10,
                              color: kTextSecondary.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // --- Input Area ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: kCardColorDark,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: strings.typeAMessage,
                    hintStyle: TextStyle(
                      color: kTextSecondary.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: kBgColorDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sending ? null : _handleSend(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _sending ? null : _handleSend,
                icon: const Icon(Icons.send_rounded),
                color: kPrimaryColor,
                iconSize: 28,
                tooltip: strings.send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FanDetailsHeader extends StatelessWidget {
  const _FanDetailsHeader({
    required this.fan,
    required this.onRefresh,
    required this.onDelete,
  });

  final Fan fan;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final name = fan.displayName.isNotEmpty ? fan.displayName : fan.username;

    // Calculate time since last contact
    String sinceContact = '';
    if (fan.lastMessageAt != null) {
      final now = DateTime.now();
      final difference = now.difference(fan.lastMessageAt!);
      if (difference.inDays > 0) {
        sinceContact =
            'Last contact ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        sinceContact =
            'Last contact ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        sinceContact = 'Last contact ${difference.inMinutes}m ago';
      } else {
        sinceContact = 'Just now';
      }
    }

    // Generate avatar color
    final avatarColor = Color(
      (name.hashCode & 0xFFFFFF) | 0xFF000000,
    ).withOpacity(1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      color: kCardColorDark.withLightness(0.02),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: avatarColor,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Name
                Text(
                  name,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Metadata Row
                Row(
                  children: [
                    Text(
                      '@${fan.username.isNotEmpty ? fan.username : '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 12, width: 1, color: Colors.white24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ID: ${fan.fanvueId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextSecondary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (sinceContact.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: kTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sinceContact,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: kTextSecondary),
            tooltip: strings.refreshMessages,
          ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: kCardColorDark,
                  title: Text(
                    strings.deleteFanTitle,
                    style: const TextStyle(color: kTextPrimary),
                  ),
                  content: Text(
                    strings.deleteFanConfirm(name),
                    style: const TextStyle(color: kTextSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        strings.cancel,
                        style: const TextStyle(color: kTextSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: kDangerColor,
                      ),
                      child: Text(strings.delete),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await onDelete();
              }
            },
            icon: const Icon(Icons.delete_outline, color: kDangerColor),
            tooltip: strings.delete,
          ),
        ],
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
