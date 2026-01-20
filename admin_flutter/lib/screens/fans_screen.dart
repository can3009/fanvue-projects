import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/fans_controller.dart';
import '../data/models/message.dart';
import '../widgets/section_card.dart';

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
                    await ref.read(fansControllerProvider.notifier).loadFans(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => ref
                    .read(fansControllerProvider.notifier)
                    .loadCreators(),
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
                child: SectionCard(
                  title: 'Fans',
                  child: state.fans.isEmpty
                      ? const Text('No fans yet.')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: state.fans.length,
                          itemBuilder: (context, index) {
                            final fan = state.fans[index];
                            final name = fan.displayName.isNotEmpty
                                ? fan.displayName
                                : fan.username;
                            return ListTile(
                              title: Text(name.toString()),
                              subtitle: Text(fan.fanvueId),
                              selected: state.selectedFan?.id == fan.id,
                              onTap: () async {
                                await ref
                                    .read(fansControllerProvider.notifier)
                                    .loadMessages(fan);
                              },
                            );
                          },
                        ),
                ),
              ),
              Expanded(
                child: state.selectedFan == null
                    ? const Center(child: Text('Select a fan'))
                    : _ChatPanel(
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
    required this.messages,
    required this.onSend,
    required this.onRefresh,
  });

  final List<ChatMessage> messages;
  final Future<void> Function(String message) onSend;
  final Future<void> Function() onRefresh;

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
            Row(
              children: [
                Text(
                  'Conversation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.messages.length,
                itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isOutbound = message.direction == 'outbound';
                return Align(
                  alignment:
                      isOutbound ? Alignment.centerRight : Alignment.centerLeft,
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
                      child: Text(message.content),
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
                    decoration: const InputDecoration(
                      labelText: 'Message',
                    ),
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
