import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/ai_service.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';

class CoreFunctionalHome extends StatefulWidget {
  const CoreFunctionalHome({super.key});

  @override
  State<CoreFunctionalHome> createState() => _CoreFunctionalHomeState();
}

class _CoreFunctionalHomeState extends State<CoreFunctionalHome> {
  final AiService _aiService = AiService();
  final TextEditingController _inputController = TextEditingController();

  // Session State
  late String _sessionId;
  String _statusMessage = "Ready";

  // Local Chat Buffer for Flushing (Memory Logic)
  final List<ConversationNode> _sessionNodes = [];

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
  }

  // --- Core Function 1: Real-time Messaging ---
  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() => _statusMessage = "Processing...");

    // 1. Log User Message (Real-time DB)
    await _aiService.logChatRealtime(_sessionId, 'user', text);

    // Add to local buffer for summarization later
    _sessionNodes.add(ConversationNode(
      id: const Uuid().v4(),
      role: Role.user,
      content: text,
      timestamp: DateTime.now(),
      scores: CognitiveScore(stabilityVsAggressive: 50, logicVsEmotion: 50, overviewVsDetail: 50, consistencyVsOpenness: 50, utilityVsCuriosity: 50, temporalVsPerpetual: 50),
      logicSchema: "",
      metadata: {},
    ));

    try {
      // 2. Get AI Response (Stream)
      // Note: We construct a minimal history for context
      final history = _sessionNodes.map((n) => {'role': n.role.toString().split('.').last, 'text': n.content}).toList();

      final stream = await _aiService.chatWithProStream(history);
      String fullResponse = "";

      await for (final chunk in stream) {
        fullResponse += chunk;
      }

      // 3. Log AI Message (Real-time DB)
      await _aiService.logChatRealtime(_sessionId, 'ai', fullResponse);

      _sessionNodes.add(ConversationNode(
        id: const Uuid().v4(),
        role: Role.assistant,
        content: fullResponse,
        timestamp: DateTime.now(),
        scores: CognitiveScore(stabilityVsAggressive: 50, logicVsEmotion: 50, overviewVsDetail: 50, consistencyVsOpenness: 50, utilityVsCuriosity: 50, temporalVsPerpetual: 50),
        logicSchema: "",
        metadata: {},
      ));

      setState(() => _statusMessage = "AI Response Logged.");

    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    }
  }

  // --- Core Function 2: Flush & Summarize ---
  Future<void> _handleFlush() async {
    if (_sessionNodes.isEmpty) {
      setState(() => _statusMessage = "No data to flush.");
      return;
    }

    setState(() => _statusMessage = "Summarizing & Flushing...");

    try {
      // Upsert Session Master
      await _aiService.flushSession(
        _sessionNodes,
        CognitiveScore(stabilityVsAggressive: 50, logicVsEmotion: 50, overviewVsDetail: 50, consistencyVsOpenness: 50, utilityVsCuriosity: 50, temporalVsPerpetual: 50),
        _sessionId,
        clearHistory: false
      );

      setState(() => _statusMessage = "Session Flushed (Upsert Complete). Check 'documents' table.");
    } catch (e) {
      setState(() => _statusMessage = "Flush Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Core Functional Home ($_sessionId)")),
      body: Column(
        children: [
          // 1. Data Output Area (Stream from DB directly)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Listening to 'chat_logs' changes in real-time
              stream: Supabase.instance.client
                  .from('chat_logs')
                  .stream(primaryKey: ['id'])
                  .eq('session_id', _sessionId)
                  .order('created_at'),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                if (!snapshot.hasData) return const Text("Waiting for data...");

                final logs = snapshot.data!;

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      title: Text("${log['role']}: ${log['content']}"),
                      subtitle: Text(log['created_at'].toString()),
                      dense: true,
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 2, color: Colors.black),

          // 2. Status Monitor
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text("System Status: $_statusMessage"),
          ),

          // 3. Control Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Raw Input",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _handleSend, child: const Text("Send")),
              ],
            ),
          ),

          // 4. Flush Trigger
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _handleFlush,
              icon: const Icon(Icons.save),
              label: const Text("EXECUTE: Flush Session (Summarize)"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}
