import 'dart:convert';

const String inventoryType = 'inventory';
const String incidentType = 'incident';

Map<String, dynamic> buildInventoryPayload({
  required String name,
  required num quantity,
  required String unit,
  String? location,
  String? expiry,
  String? notes,
}) {
  return {
    'type': inventoryType,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'location': location,
    'expiry': expiry,
    'notes': notes,
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> buildIncidentPayload({
  required String title,
  required String description,
  required String severity,
  String? symptoms,
  String? actionTaken,
  bool hasImage = false,
}) {
  return {
    'type': incidentType,
    'title': title,
    'description': description,
    'severity': severity,
    'symptoms': symptoms,
    'actionTaken': actionTaken,
    'hasImage': hasImage,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic>? decodeTypedPayload(String content, String expectedType) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic> && decoded['type'] == expectedType) {
      return decoded;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String encodePayload(Map<String, dynamic> payload) {
  return jsonEncode(payload);
}
