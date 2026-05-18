import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:image_picker/image_picker.dart';

import 'agent/agent_coordinator.dart';
import 'agent/agent_events.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterGemma.initialize(
    webStorageMode: WebStorageMode.cacheApi,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F4F1),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ),
      home: const ChatPage(),
    );
  }
}

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

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _agent = AgentCoordinator();
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _isInitializing = true;
  bool _isSending = false;
  String? _errorMessage;
  Uint8List? _pendingImage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _agent.initialize();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _agent.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    final hasImage = _pendingImage != null;
    if ((text.isEmpty && !hasImage) || _isSending) {
      return;
    }

    final imageBytes = _pendingImage;

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(text: text, isUser: true, imageBytes: imageBytes),
      );
      _messages.add(ChatMessage(text: '', isUser: false));
      _inputController.clear();
      _pendingImage = null;
    });
    _scrollToBottom();

    final responseIndex = _messages.length - 1;
    var assistantIndex = responseIndex;

    try {
      await for (final event in _agent.runAgentCycle(
        text,
        imageBytes: imageBytes,
      )) {
        if (!mounted) {
          return;
        }

        if (event.type == AgentEventType.toolResult) {
          setState(() {
            _messages.insert(
              assistantIndex,
              ChatMessage(text: event.data, isUser: false, isTool: true),
            );
            assistantIndex += 1;
          });
          _scrollToBottom();
          continue;
        }

        if (event.type == AgentEventType.uiRender) {
          setState(() {
            _messages.insert(
              assistantIndex,
              ChatMessage(
                text: event.data,
                isUser: false,
                contentType: MessageContentType.dynamicUi,
                uiComponentType: event.uiComponentType,
                uiData: event.uiData,
              ),
            );
            assistantIndex += 1;
          });
          _scrollToBottom();
          continue;
        }

        setState(() {
          final current = _messages[assistantIndex].text;
          _messages[assistantIndex] = ChatMessage(
            text: '$current${event.data}',
            isUser: false,
          );
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages[responseIndex] = ChatMessage(
          text: 'Error: $error',
          isUser: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildDynamicUi(ChatMessage message) {
    if (message.uiComponentType == 'html') {
      final raw = message.uiData?['html']?.toString() ?? '';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2DED8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Html(
          data: raw,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(14.0),
            ),
            'table': Style(
              backgroundColor: Colors.white,
              border: Border.all(color: const Color(0xFFE2DED8)),
            ),
          },
        ),
      );
    }

    return Text(
      message.text,
      style: const TextStyle(color: Color(0xFF1F1F1F)),
    );
  }

  Future<void> _pickImage() async {
    if (_isSending) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo library'),
                onTap: () => _handleImagePick(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => _handleImagePick(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleImagePick(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingImage = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image error: $error')),
      );
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _pendingImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma Local Chat'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF6F4F1),
        foregroundColor: const Color(0xFF1F1F1F),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return Align(
                              alignment: message.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                decoration: BoxDecoration(
                                  color: message.isUser
                                      ? const Color(0xFF1F1F1F)
                                      : message.isTool
                                          ? const Color(0xFFD9C9B6)
                                          : const Color(0xFFE2DED8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: message.contentType ==
                                        MessageContentType.dynamicUi
                                    ? _buildDynamicUi(message)
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (message.imageBytes != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                message.imageBytes!,
                                                width: 220,
                                                height: 220,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          if (message.text.isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: message.imageBytes == null
                                                    ? 0
                                                    : 10,
                                              ),
                                              child: Text(
                                                message.text,
                                                style: TextStyle(
                                                  color: message.isUser
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF1F1F1F,
                                                        ),
                                                  fontWeight: message.isTool
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6F4F1),
                          border: Border(
                            top: BorderSide(
                              color: Color(0xFFE2DED8),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_pendingImage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  height: 64,
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _pendingImage!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Image attached',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove image',
                                        onPressed: () {
                                          setState(() {
                                            _pendingImage = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Attach image',
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.add_photo_alternate),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _inputController,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                    decoration: const InputDecoration(
                                      hintText: 'Ask Gemma anything... ',
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF1F1F1F),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF1F1F1F),
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                    minLines: 1,
                                    maxLines: 4,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  width: 48,
                                  child: ElevatedButton(
                                    onPressed: _isSending ? null : _sendMessage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1F1F1F),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
