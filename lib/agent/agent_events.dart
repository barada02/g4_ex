enum AgentEventType {
  toolResult,
  responseToken,
}

class AgentEvent {
  AgentEvent({required this.type, required this.data});

  final AgentEventType type;
  final String data;
}
