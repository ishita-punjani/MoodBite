import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../models/recommendation_result.dart';
import '../home/home_controllers.dart';
import '../home/recommendation_repository.dart';

/// One bubble in the conversation. Assistant bubbles may carry dish picks.
class ChatEntry {
  const ChatEntry({required this.message, this.result});

  final ChatMessage message;
  final RecommendationResult? result;
}

class ChatState {
  const ChatState({this.entries = const [], this.sending = false, this.error});

  final List<ChatEntry> entries;
  final bool sending;

  /// Friendly message for the last failed turn; the user message stays in
  /// [entries] so Retry can resend it.
  final String? error;

  ChatState copyWith({List<ChatEntry>? entries, bool? sending, String? error, bool clearError = false}) => ChatState(
    entries: entries ?? this.entries,
    sending: sending ?? this.sending,
    error: clearError ? null : error ?? this.error,
  );
}

/// Food chat. The history lives only in this notifier (memory), is never
/// stored, and only the last [ChatRequest.maxMessages] messages are sent.
/// The area, diet and budget come from the Mood tab providers.
class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  /// Sends [text] (already validated by the screen). Needs a delivery area.
  Future<void> send(String text) async {
    if (state.sending) return;
    final entry = ChatEntry(message: ChatMessage(isUser: true, text: text.trim()));
    state = state.copyWith(entries: [...state.entries, entry], clearError: true);
    await _ask();
  }

  /// Resends the last user message after a failure.
  Future<void> retry() async {
    if (state.sending || state.error == null) return;
    state = state.copyWith(clearError: true);
    await _ask();
  }

  Future<void> _ask() async {
    final zone = ref.read(deliveryZoneProvider);
    if (zone == null) {
      state = state.copyWith(error: 'Choose your delivery area first.');
      return;
    }
    final filters = ref.read(recommendationFiltersProvider);
    state = state.copyWith(sending: true);
    try {
      final result = await ref
          .read(recommendationRepositoryProvider)
          .chat(
            ChatRequest(
              messages: [for (final e in state.entries) e.message],
              location: zone.centre,
              maxPriceInr: filters.maxPriceInr,
              diet: filters.diet,
            ),
          );
      final reply = ChatMessage(isUser: false, text: result.reply ?? 'Here are some ideas.');
      state = state.copyWith(
        entries: [
          ...state.entries,
          ChatEntry(message: reply, result: result),
        ],
        sending: false,
      );
    } catch (e) {
      state = state.copyWith(sending: false, error: friendlyError(e));
    }
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
