Let me explore the project structure first to understand what we're working with.

Listed directory g4_ex
Listed directory lib
Viewed pubspec.yaml:1-35
Viewed phases.md:1-97
Listed directory agent
Listed directory data
Listed directory services
Listed directory tools
Viewed main.dart:1-800
Viewed main.dart:800-1599
Viewed main.dart:1600-2399
Viewed agent_coordinator.dart:1-355
Viewed main.dart:2400-2959
Viewed tool_registry.dart:1-53
Viewed inventory_add_tool.dart:1-94
Viewed incident_log_tool.dart:1-93
Viewed isar_database.dart:1-42
Viewed inventory_item.dart:1-25
Viewed incident_log.dart:1-26
Viewed inventory_update_tool.dart:1-118
Viewed gemma_service.dart:1-68
Viewed base_tool.dart:1-32
Viewed protocol_lookup_tool.dart:1-146

Now I have a thorough understanding of the entire codebase. Let me compile the analysis report.

Edited aegis_project_audit.md

Here's the full audit report. I went through every file — all 8 tools, the agent coordinator, data layer, all 4 tabs, and the dialogs. Here's the TL;DR:

---

## 🔴 5 Critical Issues

1. **Dead `GemmaChatService`** — [gemma_service.dart](file:///c:/Flutter/g4_ex/lib/services/gemma_service.dart) is fully implemented but never used. If activated, it would cause a duplicate model init crash. **Just delete it.**

2. **`_sendMessage` error recovery targets the wrong message** — `responseIndex` is captured before tool events are inserted, so the `catch` block overwrites a tool result card instead of the empty assistant bubble. ([main.dart#L1018](file:///c:/Flutter/g4_ex/lib/main.dart#L1018-L1027))

3. **No multi-turn memory in the agent** — Every call to `_getToolDecision` creates a fresh session with no history. "Update what I just added" is impossible. ([agent_coordinator.dart#L165](file:///c:/Flutter/g4_ex/lib/agent/agent_coordinator.dart#L165))

4. **`AgentCoordinator.dispose()` is never called** — The Isar database and model are never cleaned up on nav transitions. ([main.dart#L151](file:///c:/Flutter/g4_ex/lib/main.dart#L151))

5. **Unique index silently destroys existing inventory** — `replace: true` on `InventoryItem.name` means adding "Bandage Roll" when one already exists silently wipes the old quantity. ([inventory_item.dart#L9](file:///c:/Flutter/g4_ex/lib/data/inventory_item.dart#L9))

---

## 🟠 5 High-Priority Flaws

- **`delta` in `inventory_update_item` allows negative quantities** — no clamp at all.
- **Incident timeline `.sort()` mutates the Isar stream list in-place** — undefined behavior with reactive streams.
- **Protocol HTML is hard-coded light theme** — renders as a jarring white box in dark mode.
- **Past expiry dates allowed** in the add-item dialog without any warning.
- **No feedback when tapping `–` on a zero-quantity item** — field responders will think UI is frozen.

---

## 🟡 Architecture Gaps

- **`main.dart` is 2,959 lines** — every widget, screen, theme, and dialog in one file. Split it.
- **`isDarkMode` prop-drilled 5 levels deep** — can just use `Theme.of(context).brightness` everywhere instead.
- **`HtmlRenderTool` is a zombie** — registered but never explicitly guided in the system prompt; reduces Gemma-2B accuracy unnecessarily.
