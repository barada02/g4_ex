import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../agent/agent_coordinator.dart';
import '../../data/inventory_item.dart';

class InventoryDashboardTab extends StatefulWidget {
  final AgentCoordinator agent;

  const InventoryDashboardTab({super.key, required this.agent});

  @override
  State<InventoryDashboardTab> createState() => _InventoryDashboardTabState();
}

class _InventoryDashboardTabState extends State<InventoryDashboardTab> {
  String _searchQuery = '';
  String? _selectedLocation;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<InventoryItem>>(
        stream: widget.agent.isar.inventoryItems
            .where()
            .watch(fireImmediately: true),
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
            final matchesSearch =
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (item.notes
                            ?.toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ??
                        false);
            final matchesLocation =
                _selectedLocation == null ||
                    item.location == _selectedLocation;
            return matchesSearch && matchesLocation;
          }).toList();

          return Column(
            children: [
              // Search & Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search supplies...',
                          prefixIcon:
                              const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF161B22)
                              : Colors.white,
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
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161B22)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF30363D)
                              : const Color(0xFFE5E5E5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedLocation,
                          dropdownColor: isDark
                              ? const Color(0xFF161B22)
                              : Colors.white,
                          hint: const Text('All Locations',
                              style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.filter_list_rounded,
                              size: 16),
                          onChanged: (val) =>
                              setState(() => _selectedLocation = val),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Locations',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            ...locations.map(
                              (loc) => DropdownMenuItem<String?>(
                                value: loc,
                                child: Text(loc,
                                    style:
                                        const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats row
              _buildStockStatsOverview(items, isDark),

              // Item list
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 40,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No medical items found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
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
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          return _buildInventoryCard(
                              filteredItems[index], isDark);
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

  Widget _buildStockStatsOverview(List<InventoryItem> items, bool isDark) {
    final total = items.length;
    final low = items.where((e) => e.quantity > 0 && e.quantity <= 10).length;
    final outOfStock = items.where((e) => e.quantity == 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildStatCard('Total Types', total.toString(), Colors.blue, isDark),
          _buildStatCard('Low Stock', low.toString(), Colors.amber, isDark),
          _buildStatCard(
              'Out of Stock', outOfStock.toString(), Colors.redAccent, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDark ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, bool isDark) {
    final qty = item.quantity;
    Color badgeColor;
    String statusLabel;
    List<BoxShadow> glowShadow;

    if (qty > 10) {
      badgeColor = const Color(0xFF00E676);
      statusLabel = 'In Stock';
      glowShadow = isDark
          ? [
              const BoxShadow(
                  color: Color(0x2200E676), blurRadius: 8, spreadRadius: 1)
            ]
          : [];
    } else if (qty > 0) {
      badgeColor = const Color(0xFFFFD54F);
      statusLabel = 'Low Stock';
      glowShadow = isDark
          ? [
              const BoxShadow(
                  color: Color(0x22FFD54F), blurRadius: 8, spreadRadius: 1)
            ]
          : [];
    } else {
      badgeColor = const Color(0xFFFF5252);
      statusLabel = 'Out Stock';
      glowShadow = isDark
          ? [
              const BoxShadow(
                  color: Color(0x22FF5252), blurRadius: 8, spreadRadius: 1)
            ]
          : [];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? const Color(0xFF30363D) : const Color(0xFFE5E5E5),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
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
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      item.location ?? 'N/A',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.history_toggle_off,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      item.expiryDate != null
                          ? _formatDate(item.expiryDate!)
                          : 'No Expiry',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                      color:
                          isDark ? Colors.grey[400] : Colors.grey[600],
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D1117)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: badgeColor.withOpacity(0.3)),
                  boxShadow: glowShadow,
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildControlBtn(
                      Icons.remove, () => _adjustQty(item, -1)),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity.toInt()} ${item.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.white : const Color(0xFF1F2937),
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
    final isDark = _isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
    );
  }

  Future<void> _adjustQty(InventoryItem item, double amt) async {
    // FIX: show feedback when already at 0 (audit issue #7).
    if (item.quantity == 0 && amt < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already at 0 — cannot go lower.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
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
      builder: (context) => AddInventoryDialog(agent: widget.agent),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── Add Inventory Dialog ────────────────────────────────────────────────────

class AddInventoryDialog extends StatefulWidget {
  final AgentCoordinator agent;

  const AddInventoryDialog({super.key, required this.agent});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Add Medical Supply',
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Item Name (e.g. Syringes)'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                              ? 'Invalid qty'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Unit (e.g. rolls, packs)'),
                      validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Enter unit'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locCtrl,
                decoration:
                    const InputDecoration(labelText: 'Location Box'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _expiryDate == null
                      ? 'Select Expiry Date'
                      : 'Expiry: ${_expiryDate!.year}-${_expiryDate!.month}-${_expiryDate!.day}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing:
                    const Icon(Icons.calendar_today, size: 18),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    // FIX: block past expiry dates (audit issue #11).
                    initialDate:
                        DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 3650)),
                  );
                  if (dt != null) setState(() => _expiryDate = dt);
                },
              ),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes / Specifications'),
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
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor),
          child: const Text('Save Supply',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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

    if (mounted) Navigator.of(context).pop();
  }
}
