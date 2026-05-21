import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';

import 'agent/agent_coordinator.dart';
import 'agent/agent_events.dart';
import 'data/incident_log.dart';
import 'data/inventory_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterGemma.initialize(
    webStorageMode: WebStorageMode.cacheApi,
  );

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aegis Field Medicine Copilot',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF00E5FF),
        cardColor: const Color(0xFF161B22),
        dividerColor: const Color(0xFF30363D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00B4D8),
          surface: Color(0xFF161B22),
          background: Color(0xFF0B0F19),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFC),
        primaryColor: const Color(0xFF007A8C),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFFE5E5E5),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007A8C),
          secondary: Color(0xFF00B4D8),
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFFAFAFC),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      ),
      home: AegisShell(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
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

class AegisShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const AegisShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<AegisShell> createState() => _AegisShellState();
}

class _AegisShellState extends State<AegisShell> {
  final AgentCoordinator _agent = AgentCoordinator();
  int _currentIndex = 0;
  bool _isInitializing = true;
  String? _errorMessage;

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
    _agent.dispose();
    super.dispose();
  }

  Widget _buildGemmaStatus() {
    final bool ready = !_isInitializing && _errorMessage == null && _agent.isReady;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ready
                ? (widget.isDarkMode ? const Color(0x2200E5FF) : const Color(0x22007A8C))
                : (widget.isDarkMode ? const Color(0x22FFB300) : const Color(0x22FF8F00)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ready
                  ? (widget.isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C))
                  : (widget.isDarkMode ? const Color(0xFFFFB300) : const Color(0xFFFF8F00)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ready ? const Color(0xFF00E676) : const Color(0xFFFFC107),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ready ? const Color(0x8800E676) : const Color(0x88FFC107),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ready ? 'Aegis Active' : 'Initializing...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ready
                      ? (widget.isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C))
                      : (widget.isDarkMode ? const Color(0xFFFFB300) : const Color(0xFFFF8F00)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      CopilotTab(agent: _agent, isDarkMode: widget.isDarkMode),
      InventoryDashboardTab(agent: _agent, isDarkMode: widget.isDarkMode),
      IncidentTimelineTab(agent: _agent, isDarkMode: widget.isDarkMode),
      HandbookTab(isDarkMode: widget.isDarkMode),
    ];

    final titles = [
      'Aegis Field Copilot',
      'Inventory Stock',
      'Incident Log',
      'Field Protocol Handbook',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        foregroundColor: widget.isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
        actions: [
          _buildGemmaStatus(),
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
            ),
          ),
        ],
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Aegis Clinical Engine...',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(child: Text('Initialization Error: $_errorMessage'))
              : IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: widget.isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Copilot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_outlined),
              activeIcon: Icon(Icons.medical_services),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Timeline',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Handbook',
            ),
          ],
        ),
      ),
    );
  }
}

class CopilotTab extends StatefulWidget {
  final AgentCoordinator agent;
  final bool isDarkMode;

  const CopilotTab({
    super.key,
    required this.agent,
    required this.isDarkMode,
  });

  @override
  State<CopilotTab> createState() => _CopilotTabState();
}

class _CopilotTabState extends State<CopilotTab> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _isSending = false;
  Uint8List? _pendingImage;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
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
      await for (final event in widget.agent.runAgentCycle(
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

  void _sendQuickPrompt(String prompt) {
    if (_isSending) {
      return;
    }
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
    if (message.uiComponentType == 'html') {
      final raw = message.uiData?['html']?.toString() ?? '';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
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
              color: widget.isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
            ),
            'table': Style(
              backgroundColor: widget.isDarkMode ? const Color(0xFF0D1117) : Colors.white,
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
              ),
            ),
            'th': Style(
              backgroundColor: widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFF6F4F1),
              color: widget.isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
            ),
            'td': Style(
              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF1F1F1F),
            ),
          },
        ),
      );
    }

    return Text(
      message.text,
      style: TextStyle(
        color: widget.isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_isSending) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
    return Container(
      color: widget.isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFF9F4EF),
      child: Column(
        children: [
          // Quick Actions Row
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
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
                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: const Text('Bleeding Protocol', style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt('Show the bleeding control protocol.'),
                        backgroundColor: widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFF6F4F1),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Add Bandages', style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt('Add 12 bandage rolls to inventory in Clinic Box A.'),
                        backgroundColor: widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFF6F4F1),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Log Incident', style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendQuickPrompt('Log incident: sprained ankle, swelling, medium severity.'),
                        backgroundColor: widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFF6F4F1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Messages Display
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Secure Field Copilot Offline',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Gemma can analyze photo attachments, log incidents, lookup medical protocols, and manage stock counts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isRedAlert = message.text.contains('🚨 **Tool Failure Diagnostic Alert**');

                      return Align(
                        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? Theme.of(context).primaryColor
                                : isRedAlert
                                    ? const Color(0xFF3A1E22)
                                    : message.isTool
                                        ? (widget.isDarkMode ? const Color(0xFF2D2620) : const Color(0xFFEFE8DD))
                                        : (widget.isDarkMode ? const Color(0xFF161B22) : const Color(0xFFE2DED8)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRedAlert
                                  ? const Color(0xFFD32F2F)
                                  : message.isUser
                                      ? Colors.transparent
                                      : widget.isDarkMode
                                          ? const Color(0xFF30363D)
                                          : const Color(0xFFE2DED8),
                              width: 1,
                            ),
                          ),
                          child: message.contentType == MessageContentType.dynamicUi
                              ? _buildDynamicUi(message)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message.imageBytes != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
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
                                          top: message.imageBytes == null ? 0 : 10,
                                        ),
                                        child: Text(
                                          message.text,
                                          style: TextStyle(
                                            color: message.isUser
                                                ? Colors.white
                                                : isRedAlert
                                                    ? const Color(0xFFFF6B6B)
                                                    : widget.isDarkMode
                                                        ? Colors.white
                                                        : const Color(0xFF1F1F1F),
                                            fontWeight: message.isTool ? FontWeight.w600 : FontWeight.normal,
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
          
          // Clear Chat Button
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton.icon(
                onPressed: _clearChat,
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text('Clear Chat History', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ),
            
          // Input Panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF161B22) : const Color(0xFFF6F4F1),
              border: Border(
                top: BorderSide(
                  color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
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
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove Attachment',
                            onPressed: () {
                              setState(() {
                                _pendingImage = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded, size: 20),
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
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter clinical directives...',
                          filled: true,
                          fillColor: widget.isDarkMode ? const Color(0xFF0D1117) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
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
                              color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2DED8),
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
                            : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
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

class InventoryDashboardTab extends StatefulWidget {
  final AgentCoordinator agent;
  final bool isDarkMode;

  const InventoryDashboardTab({
    super.key,
    required this.agent,
    required this.isDarkMode,
  });

  @override
  State<InventoryDashboardTab> createState() => _InventoryDashboardTabState();
}

class _InventoryDashboardTabState extends State<InventoryDashboardTab> {
  String _searchQuery = '';
  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<InventoryItem>>(
        stream: widget.agent.isar.inventoryItems.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          final locations = items
              .map((e) => e.location)
              .where((loc) => loc != null && loc.isNotEmpty)
              .map((e) => e!)
              .toSet()
              .toList();

          final filteredItems = items.where((item) {
            final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
            final matchesLocation = _selectedLocation == null || item.location == _selectedLocation;
            return matchesSearch && matchesLocation;
          }).toList();

          return Column(
            children: [
              // Search & Filter controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search supplies...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedLocation,
                          dropdownColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
                          hint: const Text('All Locations', style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.filter_list_rounded, size: 16),
                          onChanged: (val) {
                            setState(() {
                              _selectedLocation = val;
                            });
                          },
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Locations', style: TextStyle(fontSize: 12)),
                            ),
                            ...locations.map((loc) => DropdownMenuItem<String?>(
                                  value: loc,
                                  child: Text(loc, style: const TextStyle(fontSize: 12)),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stock Stats row
              _buildStockStatsOverview(items),

              // Supplies list
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 40,
                                color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No medical items found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildInventoryCard(item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStockStatsOverview(List<InventoryItem> items) {
    int total = items.length;
    int low = items.where((e) => e.quantity > 0 && e.quantity <= 10).length;
    int outOfStock = items.where((e) => e.quantity == 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard('Total Types', total.toString(), Colors.blue),
          _buildStatCard('Low Stock', low.toString(), Colors.amber),
          _buildStatCard('Out of Stock', outOfStock.toString(), Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final qty = item.quantity;
    Color badgeColor;
    String statusLabel;
    List<BoxShadow> glowShadow;

    if (qty > 10) {
      badgeColor = const Color(0xFF00E676);
      statusLabel = 'In Stock';
      glowShadow = widget.isDarkMode
          ? [const BoxShadow(color: Color(0x2200E676), blurRadius: 8, spreadRadius: 1)]
          : [];
    } else if (qty > 0) {
      badgeColor = const Color(0xFFFFD54F);
      statusLabel = 'Low Stock';
      glowShadow = widget.isDarkMode
          ? [const BoxShadow(color: Color(0x22FFD54F), blurRadius: 8, spreadRadius: 1)]
          : [];
    } else {
      badgeColor = const Color(0xFFFF5252);
      statusLabel = 'Out Stock';
      glowShadow = widget.isDarkMode
          ? [const BoxShadow(color: Color(0x22FF5252), blurRadius: 8, spreadRadius: 1)]
          : [];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
        boxShadow: widget.isDarkMode
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      item.location ?? 'N/A',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.history_toggle_off, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      item.expiryDate != null ? _formatDate(item.expiryDate!) : 'No Expiry',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.notes!,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF0D1117) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                  boxShadow: glowShadow,
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildControlBtn(Icons.remove, () => _adjustQty(item, -1)),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity.toInt()} ${item.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildControlBtn(Icons.add, () => _adjustQty(item, 1)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF21262D) : Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
    );
  }

  Future<void> _adjustQty(InventoryItem item, double amt) async {
    final isar = widget.agent.isar;
    await isar.writeTxn(() async {
      item.quantity = (item.quantity + amt).clamp(0.0, 9999.0);
      item.updatedAt = DateTime.now();
      await isar.inventoryItems.put(item);
    });
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddInventoryDialog(
          agent: widget.agent,
          isDarkMode: widget.isDarkMode,
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class AddInventoryDialog extends StatefulWidget {
  final AgentCoordinator agent;
  final bool isDarkMode;

  const AddInventoryDialog({
    super.key,
    required this.agent,
    required this.isDarkMode,
  });

  @override
  State<AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<AddInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '10');
  final _unitCtrl = TextEditingController(text: 'units');
  final _locCtrl = TextEditingController(text: 'Clinic Box A');
  final _notesCtrl = TextEditingController();
  DateTime? _expiryDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _locCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medical Supply', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Syringes)'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid qty' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit (e.g. rolls, packs)'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter unit' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locCtrl,
                decoration: const InputDecoration(labelText: 'Location Box'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _expiryDate == null
                      ? 'Select Expiry Date'
                      : 'Expiry: ${_expiryDate!.year}-${_expiryDate!.month}-${_expiryDate!.day}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (dt != null) {
                    setState(() {
                      _expiryDate = dt;
                    });
                  }
                },
              ),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes / Specifications'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          child: const Text('Save Supply', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final item = InventoryItem()
      ..name = _nameCtrl.text.trim()
      ..quantity = double.parse(_qtyCtrl.text.trim())
      ..unit = _unitCtrl.text.trim()
      ..location = _locCtrl.text.trim()
      ..expiryDate = _expiryDate
      ..notes = _notesCtrl.text.trim()
      ..updatedAt = DateTime.now();

    final isar = widget.agent.isar;
    await isar.writeTxn(() async {
      await isar.inventoryItems.put(item);
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class IncidentTimelineTab extends StatefulWidget {
  final AgentCoordinator agent;
  final bool isDarkMode;

  const IncidentTimelineTab({
    super.key,
    required this.agent,
    required this.isDarkMode,
  });

  @override
  State<IncidentTimelineTab> createState() => _IncidentTimelineTabState();
}

class _IncidentTimelineTabState extends State<IncidentTimelineTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<IncidentLog>>(
        stream: widget.agent.isar.incidentLogs.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!;
          logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              // Header indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      '${logs.length} logged incidents total',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Timeline feed
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 40,
                                color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'Incident logs are empty',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return IncidentTimelineCard(
                            log: log,
                            isDarkMode: widget.isDarkMode,
                            primaryColor: Theme.of(context).primaryColor,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIncidentDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
      ),
    );
  }

  void _showAddIncidentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddIncidentDialog(
          agent: widget.agent,
          isDarkMode: widget.isDarkMode,
        );
      },
    );
  }
}

class IncidentTimelineCard extends StatefulWidget {
  final IncidentLog log;
  final bool isDarkMode;
  final Color primaryColor;

  const IncidentTimelineCard({
    super.key,
    required this.log,
    required this.isDarkMode,
    required this.primaryColor,
  });

  @override
  State<IncidentTimelineCard> createState() => _IncidentTimelineCardState();
}

class _IncidentTimelineCardState extends State<IncidentTimelineCard> {
  bool _isExpanded = false;

  void _showImageLightbox(BuildContext context, List<int> bytes) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final severity = widget.log.severity.toLowerCase();
    Color severityColor;
    if (severity == 'high') {
      severityColor = const Color(0xFFFF5252);
    } else if (severity == 'medium') {
      severityColor = const Color(0xFFFFAB40);
    } else {
      severityColor = const Color(0xFF4CAF50);
    }

    final hasImage = widget.log.imageBytes != null && widget.log.imageBytes!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        children: [
          // Header / Tap Action
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Severity circle indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.isDarkMode
                          ? [BoxShadow(color: severityColor.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.log.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(widget.log.createdAt),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.image, size: 16, color: widget.primaryColor),
                    ),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Details with Smooth Anim
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoField('Description', widget.log.description),
                            const SizedBox(height: 8),
                            if (widget.log.symptoms != null && widget.log.symptoms!.isNotEmpty) ...[
                              _buildInfoField('Symptoms Observed', widget.log.symptoms!),
                              const SizedBox(height: 8),
                            ],
                            if (widget.log.actionTaken != null && widget.log.actionTaken!.isNotEmpty)
                              _buildInfoField('Immediate Action Taken', widget.log.actionTaken!),
                          ],
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showImageLightbox(context, widget.log.imageBytes!),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  Uint8List.fromList(widget.log.imageBytes!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF1F2937),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} @ '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class AddIncidentDialog extends StatefulWidget {
  final AgentCoordinator agent;
  final bool isDarkMode;

  const AddIncidentDialog({
    super.key,
    required this.agent,
    required this.isDarkMode,
  });

  @override
  State<AddIncidentDialog> createState() => _AddIncidentDialogState();
}

class _AddIncidentDialogState extends State<AddIncidentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  String _severity = 'medium';
  Uint8List? _imageBytes;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _symptomsCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Emergency Incident', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Incident Title (e.g. Sprained Wrist)'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(labelText: 'Severity Level'),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _severity = val;
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low Severity (Jade Green)')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium Severity (Orange)')),
                  DropdownMenuItem(value: 'high', child: Text('High Severity (Neon Red)')),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description / Context'),
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter details' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _symptomsCtrl,
                decoration: const InputDecoration(labelText: 'Symptoms Observed'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _actionCtrl,
                decoration: const InputDecoration(labelText: 'Immediate Treatment Applied'),
              ),
              const SizedBox(height: 12),
              
              // Attachment segment
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    label: const Text('Snap Photo', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageBytes == null
                        ? Text(
                            'No photo attached',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _imageBytes!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          child: const Text('Save Incident', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final log = IncidentLog()
      ..title = _titleCtrl.text.trim()
      ..description = _descCtrl.text.trim()
      ..severity = _severity
      ..symptoms = _symptomsCtrl.text.trim()
      ..actionTaken = _actionCtrl.text.trim()
      ..imageBytes = _imageBytes
      ..createdAt = DateTime.now();

    final isar = widget.agent.isar;
    await isar.writeTxn(() async {
      await isar.incidentLogs.put(log);
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class HandbookTab extends StatefulWidget {
  final bool isDarkMode;

  const HandbookTab({super.key, required this.isDarkMode});

  @override
  State<HandbookTab> createState() => _HandbookTabState();
}

class _HandbookTabState extends State<HandbookTab> {
  List<dynamic> _protocols = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProtocols();
  }

  Future<void> _loadProtocols() async {
    try {
      final jsonString = await rootBundle.loadString('assets/protocols.json');
      final data = json.decode(jsonString);
      setState(() {
        _protocols = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _protocols.where((p) {
      final titleMatches = p['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final keywordsList = p['keywords'] as List<dynamic>? ?? [];
      final keywordMatches = keywordsList.any((k) => k.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      return titleMatches || keywordMatches;
    }).toList();

    return Column(
      children: [
        // Protocol search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Search bleeding, burns, sprains...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                ),
              ),
            ),
          ),
        ),

        // Grid listing
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No protocols found.',
                    style: TextStyle(color: widget.isDarkMode ? Colors.white60 : Colors.black54),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final protocol = filtered[index];
                    return _buildProtocolGridCard(protocol);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProtocolGridCard(dynamic protocol) {
    IconData icon;
    Color iconColor;

    final id = protocol['id'].toString();
    if (id.contains('bleeding')) {
      icon = Icons.healing_outlined;
      iconColor = const Color(0xFFFF5252);
    } else if (id.contains('burn')) {
      icon = Icons.local_fire_department_outlined;
      iconColor = const Color(0xFFFFAB40);
    } else {
      icon = Icons.directions_run_outlined;
      iconColor = const Color(0xFF00E5FF);
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
      ),
      child: InkWell(
        onTap: () => _openProtocolReader(protocol),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    protocol['title'].toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(protocol['steps'] as List).length} direct steps',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProtocolReader(dynamic protocol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFFAFAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            final steps = protocol['steps'] as List<dynamic>;
            final warnings = protocol['warnings'] as List<dynamic>? ?? [];
            final seekHelp = protocol['seekHelp'] as List<dynamic>? ?? [];

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ListView(
                controller: scrollController,
                children: [
                  // Pull pill
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Title
                  Text(
                    protocol['title'].toString(),
                    style: TextStyle(
                      fontFamily: GoogleFonts.lora().fontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OFFLINE CLINICAL PROTOCOL FIELD REFERENCE SHEET',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(thickness: 1.2),
                  ),
                  
                  // Steps header
                  Text(
                    'REQUIRED TREATMENT STEPS',
                    style: TextStyle(
                      fontFamily: GoogleFonts.lora().fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Steps list in Serif
                  ...List.generate(steps.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFE5E5E5),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              steps[idx].toString(),
                              style: TextStyle(
                                fontFamily: GoogleFonts.lora().fontFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: widget.isDarkMode ? const Color(0xFFE6EDF2) : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  // Warnings Alert block
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0x18FF5252) : const Color(0xFFFDF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'CRITICAL FIELD WARNINGS',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.lora().fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF5252),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...warnings.map((w) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  '• ${w.toString()}',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.lora().fontFamily,
                                    fontSize: 13,
                                    height: 1.35,
                                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF5C1D24),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // Seek Help Alert block
                  if (seekHelp.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0x1800E5FF) : const Color(0xFFEBFBFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.medical_services_outlined, color: Color(0xFF00E5FF), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'WHEN TO ESCALATE & SEEK MEDICAL HELP',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.lora().fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...seekHelp.map((sh) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  '• ${sh.toString()}',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.lora().fontFamily,
                                    fontSize: 13,
                                    height: 1.35,
                                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF005A66),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  
                  // Footer close
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDarkMode ? const Color(0xFF21262D) : Colors.grey[200],
                      foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Back to Directory'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Custom typography extension for Lora color overrides
extension TextStyleColor on TextStyle {
  TextStyle get whiteE8 => copyWith(color: const Color(0xFFE6EDF2));
}
