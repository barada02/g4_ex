import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';

import '../../agent/agent_coordinator.dart';
import '../../data/incident_log.dart';

class IncidentTimelineTab extends StatefulWidget {
  final AgentCoordinator agent;

  const IncidentTimelineTab({super.key, required this.agent});

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

          // FIX: copy list before sorting to avoid mutating the Isar stream
          // list in place (audit issue #9).
          final logs = List.of(snapshot.data!)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 16, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      '${logs.length} logged incidents total',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 40,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[600]
                                    : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'Incident logs are empty',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return IncidentTimelineCard(log: logs[index]);
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
      builder: (context) => AddIncidentDialog(agent: widget.agent),
    );
  }
}

// ─── Incident Timeline Card ──────────────────────────────────────────────────

class IncidentTimelineCard extends StatefulWidget {
  final IncidentLog log;

  const IncidentTimelineCard({super.key, required this.log});

  @override
  State<IncidentTimelineCard> createState() => _IncidentTimelineCardState();
}

class _IncidentTimelineCardState extends State<IncidentTimelineCard> {
  bool _isExpanded = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

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
                label: const Text('Dismiss',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final severity = widget.log.severity.toLowerCase();
    Color severityColor;
    if (severity == 'high') {
      severityColor = const Color(0xFFFF5252);
    } else if (severity == 'medium') {
      severityColor = const Color(0xFFFFAB40);
    } else {
      severityColor = const Color(0xFF4CAF50);
    }

    final hasImage =
        widget.log.imageBytes != null && widget.log.imageBytes!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                  color: severityColor.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1)
                            ]
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(widget.log.createdAt),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.image,
                          size: 16,
                          color: Theme.of(context).primaryColor),
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoField('Description',
                            widget.log.description, isDark),
                        if (widget.log.symptoms != null &&
                            widget.log.symptoms!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoField('Symptoms Observed',
                              widget.log.symptoms!, isDark),
                        ],
                        if (widget.log.actionTaken != null &&
                            widget.log.actionTaken!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoField('Immediate Action Taken',
                              widget.log.actionTaken!, isDark),
                        ],
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () =>
                          _showImageLightbox(context, widget.log.imageBytes!),
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
                            child: const Icon(Icons.fullscreen_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, bool isDark) {
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
            color: isDark ? Colors.white70 : const Color(0xFF1F2937),
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

// ─── Add Incident Dialog ─────────────────────────────────────────────────────

class AddIncidentDialog extends StatefulWidget {
  final AgentCoordinator agent;

  const AddIncidentDialog({super.key, required this.agent});

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

  // FIX: offer both camera and gallery (audit issue #18).
  Future<void> _pickPhoto() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => _captureFrom(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo library'),
                onTap: () => _captureFrom(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureFrom(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Log Emergency Incident',
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Incident Title (e.g. Sprained Wrist)'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration:
                    const InputDecoration(labelText: 'Severity Level'),
                onChanged: (val) {
                  if (val != null) setState(() => _severity = val);
                },
                items: const [
                  DropdownMenuItem(
                      value: 'low',
                      child: Text('Low Severity (Jade Green)')),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium Severity (Orange)')),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text('High Severity (Neon Red)')),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description / Context'),
                maxLines: 2,
                validator: (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Enter details'
                        : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _symptomsCtrl,
                decoration:
                    const InputDecoration(labelText: 'Symptoms Observed'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _actionCtrl,
                decoration: const InputDecoration(
                    labelText: 'Immediate Treatment Applied'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                    label: const Text('Attach Photo',
                        style:
                            TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageBytes == null
                        ? Text(
                            'No photo attached',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
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
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor),
          child: const Text('Save Incident',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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

    if (mounted) Navigator.of(context).pop();
  }
}
