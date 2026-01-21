import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/fans_controller.dart';
import '../data/models/fan.dart';
import '../data/models/message.dart';

class FansScreen extends ConsumerWidget {
  const FansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fansControllerProvider);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<dynamic>(
                  value: state.selectedCreator,
                  decoration: const InputDecoration(labelText: 'Creator'),
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
              const SizedBox(width: 12),
              IconButton(
                onPressed: () =>
                    ref.read(fansControllerProvider.notifier).loadCreators(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 280,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fans',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: state.fans.isEmpty
                              ? const Text('No fans yet.')
                              : ListView.builder(
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
                                            'vor ${difference.inDays} ${difference.inDays == 1 ? 'Tag' : 'Tagen'}';
                                      } else if (difference.inHours > 0) {
                                        sinceContact =
                                            'vor ${difference.inHours} ${difference.inHours == 1 ? 'Stunde' : 'Stunden'}';
                                      } else if (difference.inMinutes > 0) {
                                        sinceContact =
                                            'vor ${difference.inMinutes} Min';
                                      } else {
                                        sinceContact = 'gerade eben';
                                      }
                                    }

                                    // Generate avatar color from name
                                    final avatarColor = Color(
                                      (name.hashCode & 0xFFFFFF) | 0xFF000000,
                                    ).withOpacity(1.0);

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: avatarColor,
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
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isSelected
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : null,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (timeString.isNotEmpty)
                                            Text(
                                              timeString,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withOpacity(0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: sinceContact.isNotEmpty
                                          ? Text(
                                              sinceContact,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withOpacity(0.5),
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
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: state.selectedFan == null
                    ? const Center(child: Text('Select a fan'))
                    : _ChatPanel(
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
            ],
          ),
        ),
      ],
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fan details header
            _FanDetailsHeader(
              fan: widget.fan,
              onRefresh: widget.onRefresh,
              onDelete: widget.onDelete,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
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
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: isOutbound
                            ? const Color(0xFF233145)
                            : const Color(0xFF1B222F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isOutbound
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(message.content),
                          if (timeString.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withOpacity(0.5),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending ? null : _handleSend,
                  child: const Text('Queue reply'),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final name = fan.displayName.isNotEmpty ? fan.displayName : fan.username;

    // Calculate time since last contact
    String sinceContact = '';
    if (fan.lastMessageAt != null) {
      final now = DateTime.now();
      final difference = now.difference(fan.lastMessageAt!);
      if (difference.inDays > 0) {
        sinceContact =
            'Letzter Kontakt vor ${difference.inDays} ${difference.inDays == 1 ? 'Tag' : 'Tagen'}';
      } else if (difference.inHours > 0) {
        sinceContact =
            'Letzter Kontakt vor ${difference.inHours} ${difference.inHours == 1 ? 'Stunde' : 'Stunden'}';
      } else if (difference.inMinutes > 0) {
        sinceContact = 'Letzter Kontakt vor ${difference.inMinutes} Min';
      } else {
        sinceContact = 'Gerade eben aktiv';
      }
    }

    // Generate avatar color from name
    final avatarColor = Color(
      (name.hashCode & 0xFFFFFF) | 0xFF000000,
    ).withOpacity(1.0);

    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Name
              Row(
                children: [
                  Text(
                    'Name: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fan.displayName.isNotEmpty ? fan.displayName : '-',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Username
              Row(
                children: [
                  Text(
                    'Username: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    '@${fan.username.isNotEmpty ? fan.username : '-'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.tag,
                    size: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fan.fanvueId,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (sinceContact.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sinceContact,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.6),
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
          icon: const Icon(Icons.refresh),
          tooltip: 'Nachrichten aktualisieren',
        ),
        IconButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Fan löschen?'),
                content: Text(
                  'Möchtest du "${fan.displayName.isNotEmpty ? fan.displayName : fan.username}" wirklich löschen?\n\nAlle Nachrichten und Daten werden unwiderruflich gelöscht.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Löschen'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await onDelete();
            }
          },
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Fan löschen',
        ),
      ],
    );
  }
}
