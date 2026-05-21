enum AgentEventType {
  toolResult,
  responseToken,
  uiRender,
}

class AgentEvent {
  AgentEvent({
    required this.type,
    required this.data,
    this.uiComponentType,
    this.uiData,
  });

  final AgentEventType type;
  final String data;
  final String? uiComponentType;
  final Map<String, dynamic>? uiData;
}
