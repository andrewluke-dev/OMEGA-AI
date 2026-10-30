import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_message.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final chatRemoteDataSourceProvider =
    Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(
    ref.watch(apiClientProvider).dio,
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    ref.watch(chatRemoteDataSourceProvider),
  );
});

final sendMessageProvider = Provider<SendMessage>((ref) {
  return SendMessage(
    ref.watch(chatRepositoryProvider),
  );
});

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isRestoring;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isRestoring = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isRestoring,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isRestoring: isRestoring ?? this.isRestoring,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  static const String _storageKey = 'omega_chat_messages_v1';

  @override
  ChatState build() {
    Future.microtask(restoreMessages);

    return const ChatState(isRestoring: true);
  }

  // ========================================
  // RESTORE MESSAGES
  // ========================================

  Future<void> restoreMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedData = prefs.getString(_storageKey);

      if (savedData == null) {
        state = state.copyWith(isRestoring: false);
        return;
      }

      final decoded = jsonDecode(savedData) as List<dynamic>;

      final restoredMessages = decoded.map((item) {
        final data = item as Map<String, dynamic>;

        return Message(
          id: data['id'] as String,
          content: data['content'] as String,
          role: data['role'] == 'user'
              ? MessageRole.user
              : MessageRole.assistant,
          createdAt: DateTime.parse(
            data['createdAt'] as String,
          ),
        );
      }).toList();

      state = state.copyWith(
        messages: restoredMessages,
        isRestoring: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        error: 'Nu am putut încărca istoricul: $e',
      );
    }
  }

  // ========================================
  // SAVE MESSAGES
  // ========================================

  Future<void> saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final encoded = state.messages.map((message) {
        return {
          'id': message.id,
          'content': message.content,
          'role': message.role == MessageRole.user
              ? 'user'
              : 'assistant',
          'createdAt': message.createdAt.toIso8601String(),
        };
      }).toList();

      await prefs.setString(
        _storageKey,
        jsonEncode(encoded),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Nu am putut salva conversația: $e',
      );
    }
  }

  // ========================================
  // SEND MESSAGE
  // ========================================

  Future<void> send(String text) async {
    final content = text.trim();

    if (content.isEmpty ||
        state.isLoading ||
        state.isRestoring) {
      return;
    }

    final userMessage = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    await saveMessages();

    try {
      final reply = await ref.read(sendMessageProvider)(content);

      final aiMessage = Message(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        content: reply,
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      await saveMessages();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Nu s-a putut contacta OMEGA AI: $e',
      );
    }
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);