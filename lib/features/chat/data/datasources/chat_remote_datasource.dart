import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRemoteDataSource {
  final Dio dio;

  static const String _conversationKey =
      'omega_conversation_id_v1';

  String? _conversationId;

  ChatRemoteDataSource(this.dio);

  // ==========================================
  // RESTORE CONVERSATION ID
  // ==========================================

  Future<void> _restoreConversationId() async {
    if (_conversationId != null) return;

    final prefs = await SharedPreferences.getInstance();

    _conversationId = prefs.getString(_conversationKey);
  }

  // ==========================================
  // SAVE CONVERSATION ID
  // ==========================================

  Future<void> _saveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_conversationKey, id);

    _conversationId = id;
  }

  // ==========================================
  // SEND MESSAGE
  // ==========================================

  Future<String> sendMessage(String message) async {
    // Recuperăm conversația salvată anterior.
    await _restoreConversationId();

    final response = await dio.post(
      '/chat',
      data: {
        'message': message,
        'conversation_id': _conversationId,
        'collaboration': false,
      },
    );

    final data = response.data;

    if (data is! Map ||
        data['response'] is! String ||
        data['conversation_id'] is! String) {
      throw const FormatException(
        'Răspuns invalid de la server.',
      );
    }

    final conversationId = data['conversation_id'] as String;

    // Salvăm ID-ul pentru următoarea pornire.
    await _saveConversationId(conversationId);

    return data['response'] as String;
  }
}