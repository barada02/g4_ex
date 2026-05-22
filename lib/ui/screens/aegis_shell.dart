import 'package:flutter/material.dart';

import '../../agent/agent_coordinator.dart';
import '../tabs/copilot_tab.dart';
import '../tabs/handbook_tab.dart';
import '../tabs/incidents_tab.dart';
import '../tabs/inventory_tab.dart';

class AegisShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AgentCoordinator agent;

  const AegisShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.agent,
  });

  @override
  State<AegisShell> createState() => _AegisShellState();
}

class _AegisShellState extends State<AegisShell> {
  int _currentIndex = 0;

  // FIX: cache tab list once — prevents 4 tab constructors from running on
  // every navigation state change (audit issue #14).
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      CopilotTab(agent: widget.agent),
      InventoryDashboardTab(agent: widget.agent),
      IncidentTimelineTab(agent: widget.agent),
      const HandbookTab(),
    ];
  }

  Widget _buildGemmaStatus() {
    final bool ready = widget.agent.isReady;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ready
                ? (isDarkMode
                    ? const Color(0x2200E5FF)
                    : const Color(0x22007A8C))
                : (isDarkMode
                    ? const Color(0x22FFB300)
                    : const Color(0x22FF8F00)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ready
                  ? (isDarkMode
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFF007A8C))
                  : (isDarkMode
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFFF8F00)),
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
                  color: ready
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFFC107),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ready
                          ? const Color(0x8800E676)
                          : const Color(0x88FFC107),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
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
                      ? (isDarkMode
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF007A8C))
                      : (isDarkMode
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFFF8F00)),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const titles = [
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
        backgroundColor:
            isDarkMode ? const Color(0xFF161B22) : Colors.white,
        foregroundColor:
            isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
        actions: [
          _buildGemmaStatus(),
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round_outlined,
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? const Color(0xFF30363D)
                  : const Color(0xFFE5E5E5),
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
          backgroundColor:
              isDarkMode ? const Color(0xFF161B22) : Colors.white,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: isDarkMode
              ? const Color(0xFF8B949E)
              : const Color(0xFF6B7280),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
