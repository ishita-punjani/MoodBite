import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/copy.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/dish_recommendation.dart';
import '../../widgets/brand.dart';
import '../../widgets/recommendation_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../home/area_picker.dart';
import '../home/home_controllers.dart';
import 'chat_controller.dart';

/// Ask tab: a small food chat on the `recommend` Edge Function (chat mode).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _counterFrom = 250;

  final _input = TextEditingController();
  String? _inputError;

  /// A valid message waiting for the user to choose a delivery area.
  String? _pending;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final error = Validators.chatMessage(raw);
    setState(() => _inputError = error);
    if (error != null || ref.read(chatControllerProvider).sending) return;
    final text = raw.trim();
    if (ref.read(deliveryZoneProvider) == null) {
      _input.text = text;
      setState(() => _pending = text);
      return;
    }
    _input.clear();
    setState(() => _pending = null);
    ref.read(chatControllerProvider.notifier).send(text);
  }

  Future<void> _chooseArea() async {
    final zone = await showAreaPicker(context);
    if (zone == null || !mounted) return;
    final pending = _pending;
    if (pending != null) _submit(pending);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final zone = ref.watch(deliveryZoneProvider);
    final filters = ref.watch(recommendationFiltersProvider);
    final filterText = [
      filters.diet.label,
      if (filters.maxPriceInr != null) 'up to ₹${filters.maxPriceInr}',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: const BrandTitle('Ask'), actions: const [ProfileAvatarButton()]),
      body: SafeArea(
        child: Column(
          children: [
            _ContextRow(
              label: zone == null ? 'Choose delivery area' : 'Delivering to ${zone.name} · $filterText',
              onTap: _chooseArea,
            ),
            Expanded(
              child: chat.entries.isEmpty && !chat.sending && chat.error == null
                  ? _EmptyChat(onSuggestion: _submit)
                  : _Conversation(chat: chat),
            ),
            if (zone == null) _AreaPrompt(waiting: _pending != null, onChoose: _chooseArea),
            _InputBar(
              controller: _input,
              errorText: _inputError,
              sending: chat.sending,
              counterFrom: _counterFrom,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Tap to change the area.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.place, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyView(
            emoji: '💬',
            title: 'Ask me about food',
            message: 'Tell me your mood or a craving and I will find dishes near you.',
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final text in AppCopy.chatSuggestions)
                ActionChip(label: Text(text), onPressed: () => onSuggestion(text)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Newest message at the bottom: the list is reversed, so index 0 is the bottom.
class _Conversation extends ConsumerWidget {
  const _Conversation({required this.chat});

  final ChatState chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[
      if (chat.sending) const _TypingBubble(),
      if (chat.error != null)
        _ErrorBubble(message: chat.error!, onRetry: () => ref.read(chatControllerProvider.notifier).retry()),
      for (final entry in chat.entries.reversed) _Bubble(entry: entry),
    ];
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) => items[index],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final result = entry.result;
    final textTheme = Theme.of(context).textTheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.85;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Text(message.text, style: textTheme.bodyLarge?.copyWith(color: AppColors.onPrimary)),
            ),
          ),
        ),
      );
    }

    final picks = result?.picks.take(5).toList() ?? const <DishRecommendation>[];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result != null) ...[
                      SourceBadge(source: result.source, label: result.source.replyLabel),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(message.text, style: textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            for (final pick in picks) ...[
              const SizedBox(height: AppSpacing.sm),
              RecommendationCard(
                rec: pick,
                source: result!.source,
                moodId: result.moodId,
                reason: pick.reason,
                imageHeight: 100,
                showBadge: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  final _quip = AppCopy.randomQuip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: 'MoodBite is typing. $_quip',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(_quip, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline prompt shown while no delivery area is chosen.
class _AreaPrompt extends StatelessWidget {
  const _AreaPrompt({required this.waiting, required this.onChoose});

  final bool waiting;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryTint,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              waiting
                  ? 'Choose your delivery area and I will send your message.'
                  : 'Choose your delivery area so I can find dishes near you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: onChoose,
            // The theme's filled buttons are full width; in a Row they must size to their label.
            style: FilledButton.styleFrom(minimumSize: const Size(64, kMinTouchTarget)),
            child: const Text('Choose area'),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.errorText,
    required this.sending,
    required this.counterFrom,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool sending;
  final int counterFrom;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 3,
              maxLength: Validators.maxChatLength,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: onSubmit,
              buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
                  currentLength >= counterFrom ? Text('$currentLength/$maxLength') : null,
              decoration: InputDecoration(labelText: 'Message', hintText: AppCopy.chatHint, errorText: errorText),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: IconButton.filled(
              tooltip: 'Send',
              onPressed: sending ? null : () => onSubmit(controller.text),
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}
