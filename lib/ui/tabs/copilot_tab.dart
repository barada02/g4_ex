import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../agent/agent_coordinator.dart';
import '../../agent/agent_events.dart';
import '../../models/chat_message.dart';

class CopilotTab extends StatefulWidget {
  final AgentCoordinator agent;

  const CopilotTab({super.key, required this.agent});

  @override
  State<CopilotTab> createState() => _CopilotTabState();
}

class _CopilotTabState extends State<CopilotTab>
    with TickerProviderStateMixin {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _isSending = false;
  Uint8List? _pendingImage;

  // Speech-to-text
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  late AnimationController _micAnimationController;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Eagerly init speech so permissions are resolved before first tap.
    _initSpeech();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _micAnimationController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'notListening' || status == 'done') &&
              mounted &&
              _isListening) {
            setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech error: $errorNotification');
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Speech recognition error: ${errorNotification.errorMsg}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
      );
      if (mounted) setState(() => _speechEnabled = available);
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled) await _initSpeech();

    if (_speechEnabled) {
      if (_isListening) {
        await _stopListening();
      } else {
        await _startListening();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Speech recognition is not available or permission denied.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _lastWords = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _lastWords = result.recognizedWords;
            if (_lastWords.isNotEmpty) {
              _inputController.text = _lastWords;
              _inputController.selection = TextSelection.fromPosition(
                TextPosition(offset: _inputController.text.length),
              );
            }
          });
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Widget _buildMicButton() {
    final isDark = _isDark;
    if (!_isListening) {
      return IconButton(
        tooltip: 'Voice Dictation',
        onPressed: _toggleListening,
        icon: Icon(
          Icons.mic_none_rounded,
          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _micAnimationController,
      builder: (context, child) {
        final scale = 1.0 + (_micAnimationController.value * 0.25);
        final opacity = 0.8 - (_micAnimationController.value * 0.6);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF5252).withOpacity(opacity),
                  width: 3.0 * scale,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Stop Dictation',
              onPressed: _toggleListening,
              icon: const Icon(Icons.mic_rounded, color: Color(0xFFFF5252)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    final hasImage = _pendingImage != null;
    if ((text.isEmpty && !hasImage) || _isSending) return;

    final imageBytes = _pendingImage;

    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(text: text, isUser: true, imageBytes: imageBytes));
      _messages.add(ChatMessage(text: '', isUser: false));
      _inputController.clear();
      _pendingImage = null;
    });
    _scrollToBottom();

    // Track the assistant bubble index separately so inserts don't break it.
    var assistantIndex = _messages.length - 1;

    try {
      await for (final event in widget.agent.runAgentCycle(
        text,
        imageBytes: imageBytes,
      )) {
        if (!mounted) return;

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
      if (!mounted) return;
      // FIX: use assistantIndex (not a stale captured index) so we overwrite
      // the correct empty bubble, not a tool result card (audit issue #4).
      setState(() {
        _messages[assistantIndex] = ChatMessage(
          text: 'Error: $error',
          isUser: false,
        );
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendQuickPrompt(String prompt) {
    if (_isSending) return;
    _inputController.text = prompt;
    _sendMessage();
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
    final isDark = _isDark;
    if (message.uiComponentType == 'html') {
      final raw = message.uiData?['html']?.toString() ?? '';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
          ),
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
              color: isDark ? Colors.white : const Color(0xFF1F1F1F),
            ),
            'table': Style(
              backgroundColor:
                  isDark ? const Color(0xFF0D1117) : Colors.white,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE2DED8),
              ),
            ),
            'th': Style(
              backgroundColor:
                  isDark ? const Color(0xFF21262D) : const Color(0xFFF6F4F1),
              color: isDark ? Colors.white : const Color(0xFF1F1F1F),
            ),
            'td': Style(
              color: isDark ? Colors.white70 : const Color(0xFF1F1F1F),
            ),
          },
        ),
      );
    }

    return Text(
      message.text,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1F1F1F),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    final isDark = _isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
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
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _pendingImage = bytes);
    } catch (error) {
      if (!mounted) return;
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
    final isDark = _isDark;

    return Container(
      color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF9F4EF),
      child: Column(
        children: [
          // Quick Actions Row
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE2DED8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: const Text('Bleeding Protocol',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt(
                            'Show the bleeding control protocol.'),
                        backgroundColor: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFF6F4F1),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Add Bandages',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt(
                            'Add 12 bandage rolls to inventory in Clinic Box A.'),
                        backgroundColor: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFF6F4F1),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Log Incident',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt(
                            'Log incident: sprained ankle, swelling, medium severity.'),
                        backgroundColor: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFF6F4F1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Secure Field Copilot Offline',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Gemma can analyze photo attachments, log incidents, lookup medical protocols, and manage stock counts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isRedAlert = message.text
                          .contains('🚨 **Tool Failure Diagnostic Alert**');

                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? Theme.of(context).primaryColor
                                : isRedAlert
                                    ? const Color(0xFF3A1E22)
                                    : message.isTool
                                        ? (isDark
                                            ? const Color(0xFF2D2620)
                                            : const Color(0xFFEFE8DD))
                                        : (isDark
                                            ? const Color(0xFF161B22)
                                            : const Color(0xFFE2DED8)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRedAlert
                                  ? const Color(0xFFD32F2F)
                                  : message.isUser
                                      ? Colors.transparent
                                      : isDark
                                          ? const Color(0xFF30363D)
                                          : const Color(0xFFE2DED8),
                              width: 1,
                            ),
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
                                                : isRedAlert
                                                    ? const Color(0xFFFF6B6B)
                                                    : isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1F1F1F),
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

          // Clear button
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton.icon(
                onPressed: _clearChat,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.redAccent),
                label: const Text('Clear Chat History',
                    style:
                        TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ),

          // Input Panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF161B22) : const Color(0xFFF6F4F1),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2DED8),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _pendingImage!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Visual attachment ready',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove Attachment',
                            onPressed: () =>
                                setState(() => _pendingImage = null),
                            icon:
                                const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Attach Image',
                      onPressed: _pickImage,
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildMicButton(),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'Listening... speak now'
                              : 'Enter clinical directives...',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0D1117)
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF30363D)
                                  : const Color(0xFFE2DED8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 1.2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF30363D)
                                  : const Color(0xFFE2DED8),
                            ),
                          ),
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
