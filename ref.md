We will use Isar Database. It is incredibly fast, runs entirely on-device, features clean asynchronous data streams, and does not require complex SQL query strings—making it much easier for Gemma 4 to interact with.
In this experiment, your agent will be able to Save local notes, Search through logs, and Delete tasks entirely through natural language chat.
------------------------------
## Step 1: Add Dependencies (pubspec.yaml)
Add Isar and its code generator tools to your project:

dependencies:
  flutter:
    sdk: flutter
  flutter_gemma: ^0.15.3
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
dev_dependencies:
  isar_generator: ^3.1.0+1
  build_runner: ^2.4.8

------------------------------
## Step 2: Define the Local Memory Model (note.dart)
Create a file named note.dart. This is the database table schema that your agent will read and write to.

import 'package:isar/isar.dart';
part 'note.g.dart';

@collectionclass Note {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  late String content;
  
  late DateTime createdAt;
}

Run flutter pub run build_runner build in your project terminal to generate the underlying database files.
------------------------------
## Step 3: Build the Database Agent Engine (db_agent.dart)
This engine initializes Isar, describes the database operations to Gemma 4, and routes the generated JSON structure to physical database changes.

import 'dart:convert';import 'package:flutter/material.dart';import 'package:flutter_gemma/flutter_gemma.dart';import 'package:isar/isar.dart';import 'package:path_provider/path_provider.dart';import 'note.dart'; // Import your Note schema
class DbAgentFramework {
  late Isar _isar;
  bool _isDbReady = false;

  /// 1. Initialize local sandboxed database
  Future<void> initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema],
      directory: dir.path,
    );
    _isDbReady = true;
  }

  /// 2. Tool instructions detailing DB constraints for Gemma 4
  final String _systemInstructions = '''
You are an on-device personal data agent managing a local notes database.
You must help the user organize their data by selecting the best tool.
Always respond using a single valid JSON object. Do not wrap code blocks in markdown formatting.

Available Database Tools:
1. "db_insert_note"
   Description: Use this when the user wants to remember, save, write, or log an entry.
   Arguments: {"title": "Short title", "content": "Full detail sentence"}

2. "db_search_notes"
   Description: Use this when the user asks to find, check, search, or look up previous records.
   Arguments: {"searchTerm": "Keyword to look up"}

3. "db_delete_all_notes"
   Description: Use this only when the user explicitly requests to clear or delete everything.
   Arguments: {}

If the user is just saying hello or asking general questions, use this format:
{"tool": "none", "reply": "Your friendly reply here"}''';

  /// 3. Core Agent Loop (Reason -> Call -> Local Action)
  Future<String> runDatabaseCycle(String userQuery) async {
    if (!_isDbReady) return "Database layer initializing...";

    final model = await FlutterGemma.getActiveModel(maxTokens: 256);
    final session = await model.createSession(temperature: 0.0);

    await session.addQueryChunk(Message(text: _systemInstructions, isUser: false));
    await session.addQueryChunk(Message(text: userQuery, isUser: true));

    StringBuffer responseBuffer = StringBuffer();
    await for (final chunk in session.getResponseAsync()) {
      responseBuffer.write(chunk);
    }
    await session.close();

    return await _executeDatabaseAction(responseBuffer.toString().trim());
  }

  /// 4. Execution Layer interacting directly with Isar
  Future<String> _executeDatabaseAction(String jsonString) async {
    try {
      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      final String tool = parsed['tool'] ?? 'none';
      final Map<String, dynamic> args = parsed['arguments'] ?? {};

      switch (tool) {
        case 'db_insert_note':
          final newNote = Note()
            ..title = args['title'] ?? 'Untitled'
            ..content = args['content'] ?? ''
            ..createdAt = DateTime.now();

          // Save synchronously into local disk storage via write transaction
          await _isar.writeTxn(() => _isar.notes.put(newNote));
          return "💾 [Agent Action]: Successfully written to database!\nSaved: \"${newNote.title}\"";

        case 'db_search_notes':
          final String query = args['searchTerm'] ?? '';
          // Query Isar local indices instantly without string matches or indexing delay
          final matches = await _isar.notes
              .filter()
              .titleContains(query, caseSensitive: false)
              .or()
              .contentContains(query, caseSensitive: false)
              .findAll();

          if (matches.isEmpty) return "🔍 [Agent Action]: Searched local storage for '$query' but found 0 results.";
          
          String resultsText = "🔍 [Agent Action]: Found ${matches.length} matches:\n";
          for (var note in matches) {
            resultsText += "- [${note.title}]: ${note.content}\n";
          }
          return resultsText;

        case 'db_delete_all_notes':
          int count = await _isar.notes.count();
          await _isar.writeTxn(() => _isar.notes.clear());
          return "🗑️ [Agent Action]: Completely wiped storage database. Cleared $count records.";

        case 'none':
          return parsed['reply'] ?? "Conversation token empty.";

        default:
          return "⚠️ Unknown database operation targeted: $tool";
      }
    } catch (e) {
      return "💥 Parsing Breakdown. Output did not respect tool parameters.\nRaw String: $jsonString";
    }
  }
}

------------------------------


If you want to move forward from here, let me know if you would like to bind this framework directly to a ListView UI so the notes update dynamically on the device screen while the user chats with the model.

