import '../repositories/chat_repository.dart';

class SendMessage {
  final ChatRepository repository;

  const SendMessage(this.repository);

  Future<String> call(String message) {
    if (message.trim().isEmpty) {
      throw ArgumentError('Mesajul nu poate fi gol.');
    }

    return repository.sendMessage(message.trim());
  }
}