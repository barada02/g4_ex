 1. Dynamic UI Render PipelineInstead of replying with plain text or Markdown, the agent can output custom visual interfaces based on what the user asks for.How it WorksYou create a specialized base tool called a UiRenderTool.When the user asks for data visualization (e.g., "Show me a summary of my tasks"), the agent outputs a strict JSON payload containing a UI component identifier and the filtered raw data.Your Flutter UI captures this structural payload and switches dynamically from a standard text message chat bubble to a rich native widget.Example Payload Blueprintjson{
  "tool": "render_ui_component",
  "arguments": {
    "component_type": "task_completion_pie_chart",
    "dataset": { "completed": 12, "pending": 4 }
  }
}
Use code with caution.Flutter View Layer ImplementationIn your Flutter layout building method, map the tool's structured output directly to specialized widgets:dartWidget buildAgentResponse(Map<String, dynamic> agentJson) {
  if (agentJson['tool'] == 'render_ui_component') {
    final args = agentJson['arguments'];
    
    switch (args['component_type']) {
      case 'task_completion_pie_chart':
        return LocalPieChartWidget(data: args['dataset']);
      case 'contact_card_view':
        return LocalContactProfileWidget(data: args['dataset']);
    }
  }
  return StandardChatMessageBubble(text: agentJson['reply']);
}
Use code with caution.



No, you should not scrap or replace your chat interface.
The most elegant design pattern for an AI assistant application is a Hybrid Chat UI. This means your application remains a conversation feed, but instead of the model responding only with plain text bubbles, it can inject functional Flutter widgets directly into the message timeline [📜].
Think of it like messaging a human assistant who can instantly text you an interactive payment card, a flight ticket with a scannable QR code, or an interactive task checklist—right inside the conversation thread.
------------------------------
## Step 1: Update Your Message Model (message_model.dart)
To support this hybrid timeline, your message UI needs to know whether to display a plain text bubble or a structured UI widget. We will add a uiType and a uiData property to your core message data class.

enum MessageContentType { text, dynamicUi }
class ChatMessage {
  final String text;
  final bool isUser;
  final MessageContentType contentType;
  final String? uiComponentType; // e.g., 'task_list', 'quick_analytics'
  final Map<String, dynamic>? uiData; // Raw JSON arguments for the widget

  ChatMessage({
    required this.text,
    required this.isUser,
    this.contentType = MessageContentType.text,
    this.uiComponentType,
    this.uiData,
  });
}

------------------------------
## Step 2: Build the UI Render Tool (ui_render_tool.dart)
Now, create a new tool class that implements your BaseTool interface. This tool teaches Gemma 4 how to request a visual component instead of a text message.

import 'base_tool.dart';
class UiRenderTool extends BaseTool {
  @override
  String get name => "render_dashboard_ui";

  @override
  String get description => 
      "Use this ONLY when the user asks to see a visual summary, dashboard, charts, metric counters, or a overview layout of their statistics.";

  @override
  Map<String, dynamic> get argumentsSchema => {
    "component_type": "Must be exactly 'metric_counter_dashboard'",
    "title": "Header title of the card layout",
    "metrics": {
      "completed_tasks": "integer count",
      "pending_tasks": "integer count",
      "efficiency_percentage": "integer between 0 and 100"
    }
  };

  // The coordinator requires a string return. 
  // We return the raw JSON instruction from the tool execution layer.
  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return "UI_EXECUTION_TRIGGER:${arguments['component_type']}|${arguments['title']}|${arguments['metrics']['completed_tasks']}|${arguments['metrics']['pending_tasks']}|${arguments['metrics']['efficiency_percentage']}";
  }
}

------------------------------
## Step 3: Handle the Output in Your View Layer
When your AgentCoordinator processes the response, look out for the UI_EXECUTION_TRIGGER prefix. If it appears, parse the metrics and append a MessageContentType.dynamicUi item to your chat stream list instead of text.
## The View Renderer Widget
This component replaces a text bubble with a custom Flutter card layout when the message matches a dynamic UI content type:

import 'package:flutter/material.dart';
class ChatBubbleRenderer extends StatelessWidget {
  final ChatMessage message;

  const ChatBubbleRenderer({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // 1. If it's a normal message, render standard text layout bubbles
    if (message.contentType == MessageContentType.text) {
      return Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: message.isUser ? Colors.blueAccent : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: message.isUser ? Colors.white : Colors.black87),
          ),
        ),
      );
    }

    // 2. If the Agent requested a UI render, output a functional native widget instead
    if (message.uiComponentType == 'metric_counter_dashboard') {
      final data = message.uiData ?? {};
      
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 3))],
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  data['title'] ?? 'Assistant Analytics',
                  style: const TextStyle(fontWeight: Wood.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMetric("Done", data['completed_tasks']?.toString() ?? "0", Colors.green),
                _buildStatMetric("Pending", data['pending_tasks']?.toString() ?? "0", Colors.orange),
                _buildStatMetric("Score", "${data['efficiency_percentage']}%", Colors.purple),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

------------------------------
## How to test it
Register your new UiRenderTool inside your AgentCoordinator workspace.
When you run this query in your text input field:
👉 "Show me a dashboard summary overview of my productivity logs right now."
Gemma 4 will recognize the intent, trigger your UiRenderTool, pass your structured parameter arguments schema, and a custom Analytics Card Widget will seamlessly render inside your scrolling chat timeline layout.
Would you like to build an interactive component next, such as a Task Checklist Widget with functional checkboxes that updates your local Isar database directly when clicked?

