import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

class HandbookTab extends StatefulWidget {
  const HandbookTab({super.key});

  @override
  State<HandbookTab> createState() => _HandbookTabState();
}

class _HandbookTabState extends State<HandbookTab> {
  List<dynamic> _protocols = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _loadError;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

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
        _protocols = data as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      // FIX: surface the error with a retry option (audit issue #15).
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // FIX: show actionable error state instead of empty list (audit #15).
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Failed to load protocols',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadProtocols();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _protocols.where((p) {
      final titleMatches = p['title']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final keywordsList = p['keywords'] as List<dynamic>? ?? [];
      final keywordMatches = keywordsList.any((k) =>
          k.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      return titleMatches || keywordMatches;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Search bleeding, burns, sprains...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF161B22) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E5E5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E5E5),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No protocols found.',
                    style: TextStyle(
                        color:
                            isDark ? Colors.white60 : Colors.black54),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildProtocolGridCard(
                        filtered[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProtocolGridCard(dynamic protocol, bool isDark) {
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
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
      ),
      child: InkWell(
        onTap: () => _openProtocolReader(protocol, isDark),
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
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.grey, size: 16),
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
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(protocol['steps'] as List).length} direct steps',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProtocolReader(dynamic protocol, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? const Color(0xFF0B0F19)
          : const Color(0xFFFAFAFC),
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
            final warnings =
                protocol['warnings'] as List<dynamic>? ?? [];
            final seekHelp =
                protocol['seekHelp'] as List<dynamic>? ?? [];

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF30363D)
                            : const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    protocol['title'].toString(),
                    style: TextStyle(
                      fontFamily: GoogleFonts.lora().fontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OFFLINE CLINICAL PROTOCOL FIELD REFERENCE SHEET',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color:
                          isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(thickness: 1.2),
                  ),
                  Text(
                    'REQUIRED TREATMENT STEPS',
                    style: TextStyle(
                      fontFamily: GoogleFonts.lora().fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF007A8C),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                              color: isDark
                                  ? const Color(0xFF21262D)
                                  : const Color(0xFFE5E5E5),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
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
                                color: isDark
                                    ? const Color(0xFFE6EDF2)
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x18FF5252)
                            : const Color(0xFFFDF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFFFF5252).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFFFF5252), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'CRITICAL FIELD WARNINGS',
                                style: TextStyle(
                                  fontFamily:
                                      GoogleFonts.lora().fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF5252),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...warnings.map((w) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 3),
                                child: Text(
                                  '• ${w.toString()}',
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.lora().fontFamily,
                                    fontSize: 13,
                                    height: 1.35,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF5C1D24),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  if (seekHelp.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x1800E5FF)
                            : const Color(0xFFEBFBFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF00E5FF)
                                .withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                  Icons.medical_services_outlined,
                                  color: Color(0xFF00E5FF),
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'WHEN TO ESCALATE & SEEK MEDICAL HELP',
                                style: TextStyle(
                                  fontFamily:
                                      GoogleFonts.lora().fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF007A8C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...seekHelp.map((sh) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 3),
                                child: Text(
                                  '• ${sh.toString()}',
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.lora().fontFamily,
                                    fontSize: 13,
                                    height: 1.35,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF005A66),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF21262D)
                          : Colors.grey[200],
                      foregroundColor:
                          isDark ? Colors.white : Colors.black,
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
