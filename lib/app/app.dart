import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../features/chat/presentation/screens/chat_screen.dart';

class OmegaApp extends StatelessWidget {
  const OmegaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMEGA AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ChatScreen(),
    );
  }
}