import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  const ChatRepositoryImpl(this.remoteDataSource);

  @override
  Future<String> sendMessage(String message) {
    return remoteDataSource.sendMessage(message);
  }
}