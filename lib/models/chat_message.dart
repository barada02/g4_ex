import 'dart:typed_data';

enum MessageContentType { text, dynamicUi }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
    this.isTool = false,
    this.contentType = MessageContentType.text,
    this.uiComponentType,
    this.uiData,
  });

  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
  final bool isTool;
  final MessageContentType contentType;
  final String? uiComponentType;
  final Map<String, dynamic>? uiData;
}
