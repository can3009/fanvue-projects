import 'package:flutter/material.dart';
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
    final activeNotifier = ValueNotifier(true);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add creator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fanvueIdController,
              decoration:
                  const InputDecoration(labelText: 'Fanvue creator id'),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: activeNotifier,
              builder: (context, value, _) => SwitchListTile(
                value: value,
                onChanged: (next) => activeNotifier.value = next,
                title: const Text('Active'),
              ),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != true) return;
    await ref.read(creatorsControllerProvider.notifier).addCreator(
          displayName: displayNameController.text.trim(),
          fanvueCreatorId: fanvueIdController.text.trim(),
          isActive: activeNotifier.value,
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
        SizedBox(
          width: 280,
          child: SectionCard(
            title: 'Creators',
            actions: [
              IconButton(
                onPressed:
                    ref.read(creatorsControllerProvider.notifier).load,
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
        Expanded(
          child: state.selected == null
              ? const Center(child: Text('Select a creator'))
              : _CreatorDetail(
                  creator: state.selected!,
                  oauthConnected: state.oauthConnected,
                  onSave: (payload) => ref
                      .read(creatorsControllerProvider.notifier)
                      .saveSettings(
                        arrogance: payload.arrogance,
                        dominance: payload.dominance,
                        lewdness: payload.lewdness,
                        replyLength: payload.replyLength,
                        isActive: payload.isActive,
                      ),
                  onStartOAuth: () => _startOAuth(ref),
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
    required this.onSave,
    required this.onStartOAuth,
  });

  final Creator creator;
  final bool oauthConnected;
  final Future<void> Function(_CreatorPayload payload) onSave;
  final VoidCallback onStartOAuth;

  @override
  State<_CreatorDetail> createState() => _CreatorDetailState();
}

class _CreatorDetailState extends State<_CreatorDetail> {
  final _formKey = GlobalKey<FormState>();
  final _arroganceController = TextEditingController();
  final _dominanceController = TextEditingController();
  final _lewdnessController = TextEditingController();
  String _replyLength = 'medium';
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _CreatorDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creator.id != widget.creator.id) {
      _hydrate();
    }
  }

  void _hydrate() {
    final settings = Map<String, dynamic>.from(
      widget.creator.settings,
    );
    _arroganceController.text = (settings['arrogance'] ?? 0).toString();
    _dominanceController.text = (settings['dominance'] ?? 0).toString();
    _lewdnessController.text = (settings['lewdness'] ?? 0).toString();
    _replyLength = settings['reply_length'] ?? 'medium';
    _active = widget.creator.isActive;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await widget.onSave(
      _CreatorPayload(
        arrogance: int.tryParse(_arroganceController.text) ?? 0,
        dominance: int.tryParse(_dominanceController.text) ?? 0,
        lewdness: int.tryParse(_lewdnessController.text) ?? 0,
        replyLength: _replyLength,
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: widget.creator.displayName,
      actions: [
        Chip(
          label: Text(widget.oauthConnected ? 'OAuth connected' : 'OAuth missing'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: widget.onStartOAuth,
          child: const Text('Connect OAuth'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Active'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _arroganceController,
              decoration: const InputDecoration(labelText: 'Arrogance (0-10)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dominanceController,
              decoration: const InputDecoration(labelText: 'Dominance (0-10)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lewdnessController,
              decoration: const InputDecoration(labelText: 'Lewdness (0-10)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _replyLength,
              decoration: const InputDecoration(labelText: 'Reply length'),
              items: const [
                DropdownMenuItem(value: 'short', child: Text('Short')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'long', child: Text('Long')),
              ],
              onChanged: (value) =>
                  setState(() => _replyLength = value ?? 'medium'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorPayload {
  const _CreatorPayload({
    required this.arrogance,
    required this.dominance,
    required this.lewdness,
    required this.replyLength,
    required this.isActive,
  });

  final int arrogance;
  final int dominance;
  final int lewdness;
  final String replyLength;
  final bool isActive;
}
