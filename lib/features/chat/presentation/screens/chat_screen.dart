import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';
import '../../../vision/presentation/providers/vision_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker imagePicker = ImagePicker();

  Uint8List? selectedImage;
  bool isAnalyzingImage = false;
  bool isRestoringVision = true;

  final List<Message> visionMessages = [];
  final Map<String, Uint8List> messageImages = {};

  @override
  void initState() {
    super.initState();
    restoreVisionHistory();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<Directory> getVisionDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${appDirectory.path}/omega_vision',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<void> saveVisionHistory() async {
    final directory = await getVisionDirectory();

    final data = <Map<String, dynamic>>[];

    for (final message in visionMessages) {
      final imageBytes = messageImages[message.id];

      String? imageFilename;

      if (imageBytes != null) {
        imageFilename = '${message.id}.jpg';

        final imageFile = File(
          '${directory.path}/$imageFilename',
        );

        await imageFile.writeAsBytes(imageBytes);
      }

      data.add({
        'id': message.id,
        'content': message.content,
        'role': message.role == MessageRole.user
            ? 'user'
            : 'assistant',
        'createdAt': message.createdAt.toIso8601String(),
        'image': imageFilename,
      });
    }

    final historyFile = File(
      '${directory.path}/history.json',
    );

    await historyFile.writeAsString(
      jsonEncode(data),
    );
  }

  Future<void> restoreVisionHistory() async {
    try {
      final directory = await getVisionDirectory();

      final historyFile = File(
        '${directory.path}/history.json',
      );

      if (!await historyFile.exists()) {
        if (mounted) {
          setState(() {
            isRestoringVision = false;
          });
        }
        return;
      }

      final content = await historyFile.readAsString();
      final decoded = jsonDecode(content) as List<dynamic>;

      final restoredMessages = <Message>[];
      final restoredImages = <String, Uint8List>{};

      for (final item in decoded) {
        final data = item as Map<String, dynamic>;

        final message = Message(
          id: data['id'] as String,
          content: data['content'] as String,
          role: data['role'] == 'user'
              ? MessageRole.user
              : MessageRole.assistant,
          createdAt: DateTime.parse(
            data['createdAt'] as String,
          ),
        );

        restoredMessages.add(message);

        final imageFilename = data['image'];

        if (imageFilename is String) {
          final imageFile = File(
            '${directory.path}/$imageFilename',
          );

          if (await imageFile.exists()) {
            restoredImages[message.id] =
                await imageFile.readAsBytes();
          }
        }
      }

      if (!mounted) return;

      setState(() {
        visionMessages
          ..clear()
          ..addAll(restoredMessages);

        messageImages
          ..clear()
          ..addAll(restoredImages);

        isRestoringVision = false;
      });

      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isRestoringVision = false;
      });

      showError('Nu am putut încărca imaginile salvate: $e');
    }
  }

  void showError(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> selectImage() async {
    if (isAnalyzingImage ||
        isRestoringVision ||
        ref.read(chatProvider).isLoading) {
      return;
    }

    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        showError('Imaginea depășește limita de 10 MB.');
        return;
      }

      setState(() {
        selectedImage = bytes;
      });
    } catch (e) {
      showError('Nu am putut selecta fotografia: $e');
    }
  }

  Future<void> sendMessage() async {
    final chatState = ref.read(chatProvider);

    if (chatState.isLoading ||
        chatState.isRestoring ||
        isAnalyzingImage ||
        isRestoringVision) {
      return;
    }

    final text = controller.text.trim();
    final imageBytes = selectedImage;

    if (text.isEmpty && imageBytes == null) return;

    if (imageBytes == null) {
      controller.clear();
      await ref.read(chatProvider.notifier).send(text);
      return;
    }

    final question = text.isEmpty
        ? 'Analizează această imagine.'
        : text;

    final now = DateTime.now();
    final messageId = now.microsecondsSinceEpoch.toString();

    setState(() {
      selectedImage = null;
      controller.clear();
      isAnalyzingImage = true;

      messageImages[messageId] = imageBytes;

      visionMessages.add(
        Message(
          id: messageId,
          content: question,
          role: MessageRole.user,
          createdAt: now,
        ),
      );
    });

    scrollToBottom();

    try {
      await saveVisionHistory();
    } catch (e) {
      showError('Nu am putut salva fotografia: $e');
    }

    try {
      final response = await ref
          .read(visionRepositoryProvider)
          .analyzeImage(
            imageBytes: imageBytes,
            message: question,
          );

      if (!mounted) return;

      setState(() {
        visionMessages.add(
          Message(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            content: response,
            role: MessageRole.assistant,
            createdAt: DateTime.now(),
          ),
        );

        isAnalyzingImage = false;
      });

      await saveVisionHistory();
      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isAnalyzingImage = false;
      });

      showError('Eroare Vision AI: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        scrollToBottom();
      }
    });

    final allMessages = [
      ...state.messages,
      ...visionMessages,
    ];

    allMessages.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    final isLoading = state.isLoading ||
        state.isRestoring ||
        isAnalyzingImage ||
        isRestoringVision;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'OMEGA AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              'INTELLIGENCE SYSTEM',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: allMessages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(allMessages[index]);
                    },
                  ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('OMEGA încarcă sau analizează...'),
                ],
              ),
            ),

          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),

          _buildInput(isLoading),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF9333EA),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1)
                        .withValues(alpha: 0.3),
                    blurRadius: 45,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 55,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'OMEGA AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Intelligent AI System',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Cu ce te pot ajuta astăzi?',
              style: TextStyle(fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Message message) {
    final isUser = message.role == MessageRole.user;
    final imageBytes = messageImages[message.id];

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4F46E5)
              : const Color(0xFF171B2E),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  width: 260,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              message.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(bool isLoading) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF101422),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    bottom: 12,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          selectedImage!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedImage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF30354A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Row(
              children: [
                IconButton(
                  onPressed: isLoading ? null : selectImage,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF818CF8),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Ask OMEGA AI...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: isLoading ? null : sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                  ),
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}