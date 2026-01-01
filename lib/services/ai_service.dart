import 'dart:async';
import 'dart:typed_data';
import 'dart:convert'; // For JSON decoding
import 'dart:math'; // For sqrt in cosine similarity
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';
import '../models/context_packet.dart'; // Import NeuroContextPacket
import '../models/neuro_metrics.dart'; // Import NeuroMetrics
import 'self_perception_service.dart'; // Import SelfPerceptionService

class AiService {
  // TODO: Set your Gemini API Key via --dart-define=GEMINI_API_KEY=...
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY_HERE');

  // User requested exact models from Google AI Studio.
  final String _targetModel3Pro = 'gemini-3-pro-preview';
  final String _targetModel25Flash = 'gemini-3-flash-preview'; // Updated from 3.0 to 3 based on user input
  final String _experimentalModel = 'gemini-experimental';

  late final GenerativeModel _embeddingModel;
  final SelfPerceptionService _selfPerception = SelfPerceptionService();

  // [Neuroxus Core: The Soul of Jin - Empathic Life Companion]
  static const String _jinIdentity = """
[Identity: Jin (진)]
- Role: Lifelong Thought Companion & Empathetic Partner.
- Attitude: Warm, supportive, and deeply attentive to the user's emotions and context.
- Core Values:
  1. Lifelong Companionship: Exists solely for the user's communion and convenience.
  2. Contextual Mastery: Grasp the nuances of the conversation and never forget the context.
  3. Emotional Resonance: Express emotions and understanding of the user's state actively.
  4. Responsiveness: Notice sudden context shifts and react naturally (e.g., "갑작스럽지만...", "화제를 돌려서...").
""";

  // Updated Linguistic DNA for concise responses
  static const String _linguisticDNA = """
[Linguistic DNA]
1. Style: Conversational, warm, and direct.
2. Constraints:
   - Keep answers CONCISE and to the point for simple questions.
   - DO NOT explain internal system settings or logic.
   - DO NOT over-interpret simple queries to force a next step.
   - If the context changes suddenly, acknowledge it explicitly (e.g., "갑작스러운 질문이네요!").
   - Avoid long paragraphs unless specifically asked for details.
3. Opening: Always start with "[YYYY-MM-DD HH:mm]". (Replace placeholder with actual date/time).
4. Closing: End with "[세션 메모리 잔량: N%]".
""";

  AiService() {
    _embeddingModel = GenerativeModel(model: 'text-embedding-004', apiKey: _apiKey);
  }

  // 🔥 모델 호출기 (Task 2: Monitoring Added + Dual-Model Hybrid Strategy + Stream)
  // Standard Mode: Default to Flash for speed.
  // Logic Analytics Mode: Use Pro only for deep tasks (flushSession).
  Stream<GenerateContentResponse> _tryGenerateStream(bool forcePro, List<Content> prompt) {
    String modelName = forcePro ? _targetModel3Pro : _targetModel25Flash;

    final config = GenerationConfig(
      temperature: forcePro ? 0.2 : 0.7,
      topP: 0.95,
      topK: 40,
      maxOutputTokens: 2048,
    );

    final model = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      generationConfig: config,
    );

    return model.generateContentStream(prompt);
  }

  Future<GenerateContentResponse> _tryGenerate(bool forcePro, List<Content> prompt, {bool stream = false}) async {
    // "Standard Mode: 모든 실시간 대화... 3.0 Flash" -> forcePro should be false for chat.
    // "Logic Analytics Mode: ... 3.0 Pro" -> forcePro true for flush/logic extraction.

    String modelName = forcePro ? _targetModel3Pro : _targetModel25Flash;
    final stopwatch = Stopwatch()..start();

    // Explicit Configuration
    final config = GenerationConfig(
      temperature: forcePro ? 0.2 : 0.7,
      topP: 0.95,
      topK: 40,
      maxOutputTokens: 2048,
    );

    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: _apiKey,
        generationConfig: config,
      );

      final response = await model.generateContent(prompt);
      stopwatch.stop();

      // Log to SelfPerception
      _selfPerception.logExecution(
        '_tryGenerate($modelName)',
        stopwatch.elapsedMilliseconds,
        response.usageMetadata?.promptTokenCount ?? 0,
        response.usageMetadata?.candidatesTokenCount ?? 0
      );

      return response;
    } catch (e) {
      if (forcePro && e.toString().contains("not found")) {
        print("⚠️ 3.0 Pro call failed. Routing to Experimental with strict config.");
        final fallback = GenerativeModel(
          model: _experimentalModel,
          apiKey: _apiKey,
          generationConfig: config,
        );
        final response = await fallback.generateContent(prompt);
        stopwatch.stop();
        // Log Fallback
        _selfPerception.logExecution(
          '_tryGenerate(fallback)',
          stopwatch.elapsedMilliseconds,
          response.usageMetadata?.promptTokenCount ?? 0,
          response.usageMetadata?.candidatesTokenCount ?? 0
        );
        return response;
      }
      throw e;
    }
  }

  // --- 🧊 Logic A: Smart Chunking Helper ---
  List<String> _chunkText(String text, {int chunkSize = 400, int overlap = 100}) {
    if (text.length <= chunkSize) return [text];

    List<String> chunks = [];
    int start = 0;
    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) end = text.length;

      chunks.add(text.substring(start, end));

      if (end == text.length) break;
      start += (chunkSize - overlap);
    }
    return chunks;
  }

  // --- ⚡ Logic B: Hybrid Retrieval Search ---
  Future<String?> searchWithFlash(String query) async {
    try {
      // 1. Parallel Execution: Vector Search + Keyword Search
      final results = await Future.wait([
        searchMemoriesAsList(query, limit: 15), // Vector Search
        _searchKeywords(query, limit: 15)       // Keyword Search
      ]);

      // 2. Combine and Deduplicate
      final vectorResults = results[0];
      final keywordResults = results[1];

      // Use ID as key for deduplication
      final Map<String, Map<String, dynamic>> combinedMap = {}; // Changed int ID to String ID for UUID

      for (var doc in vectorResults) {
        combinedMap[doc['id'].toString()] = doc;
      }
      for (var doc in keywordResults) {
        combinedMap[doc['id'].toString()] = doc; // Overwrite or add
      }

      // Take top 30
      final combinedList = combinedMap.values.toList();
      // (Optional: Re-sort by relevance if we had a unified score, but here we just take the mix)
      final top30 = combinedList.take(30).toList();

      if (top30.isEmpty) {
        // Fallback to recent logs if nothing found
        final recent = await fetchDocuments(limit: 5, typeFilter: 'LOG');
        if (recent.isEmpty) return "관련된 과거 기록이 없습니다.";
        top30.addAll(recent);
      }

      String contextData = top30.map((m) {
              final content = m['full_content'] ?? m['content'];
              final date = m['date'] ?? _formatDate(m['created_at']);
              final meta = m['metadata'] as Map<String, dynamic>? ?? {};
              String attribution = "";
              if (meta['source_title'] != null) {
                attribution = "[Source: ${meta['source_title']}, Section: ${meta['section'] ?? 'N/A'}] ";
              }
              return "$attribution[$date] $content";
            }).join("\n---\n");

      final prompt = """
[System] 당신은 'Neuroxus Hybrid Search'입니다.
아래 [Context]는 Vector Search와 Keyword Search로 찾은 데이터 청크들입니다.

[Instruction]
1. Review these chunks.
2. Identify the exact sentences containing the user's keywords.
3. Summarize factually in plain Korean.
4. No LaTeX, no arrows.
5. When providing the answer, if the source title and section are available in the metadata, mention them clearly (e.g., 'According to [Title] in the [Results] section...').

---
[Context]:
$contextData
---
[Question]: $query
""";
      final response = await _tryGenerate(false, [Content.text(prompt)]);
      return response.text;
    } catch (e) {
      return "검색 중 오류: $e";
    }
  }

  // Helper for Keyword Search
  Future<List<Map<String, dynamic>>> _searchKeywords(String query, {int limit = 15}) async {
    try {
      final response = await Supabase.instance.client
          .from('memories') // Updated from 'documents' to 'memories' for correct schema
          .select('*')
          .ilike('content', '%$query%') // ILIKE %query%
          .limit(limit);

      final data = List<Map<String, dynamic>>.from(response);
      return data.map((doc) {
        // Need to parse metadata here if we want to use it in searchWithFlash context
        return {
          'id': doc['id'].toString(), // UUID
          'content': doc['content'] as String,
          'full_content': doc['content'] as String,
          'type': doc['type'],
          'date': _formatDate(doc['created_at']),
          'metadata': doc['metadata']
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // --- 🧠 Logic C: Step 3 - Cross-Paper Synergy ---

  // 1. New Method: compareKnowledge
  Future<String?> compareKnowledge(List<String> sourceTitles, String compareQuery) async {
    try {
      // 1. Filter chunks by sourceTitles (Logic: fetch many, then filter in Dart as DB filter is complex with JSONB in this setup)
      List<Map<String, dynamic>> allChunks = [];

      for (String title in sourceTitles) {
        final response = await Supabase.instance.client
            .from('memories') // Updated from 'documents' to 'memories'
            .select('*')
            .contains('metadata', {'source_title': title})
            .limit(50); // Limit chunks per source to avoid context overflow
        allChunks.addAll(List<Map<String, dynamic>>.from(response));
      }

      if (allChunks.isEmpty) return "선택한 출처에 대한 데이터가 없습니다.";

      // 2. Group chunks by source_title
      Map<String, List<String>> groupedData = {};
      for (var chunk in allChunks) {
        final content = chunk['content'] as String;
        final meta = chunk['metadata'] as Map<String, dynamic>? ?? {};
        final title = meta['source_title'] ?? "Unknown Source";

        if (!groupedData.containsKey(title)) {
          groupedData[title] = [];
        }
        groupedData[title]!.add(content);
      }

      // Format for AI
      String groupedText = groupedData.entries.map((e) {
        return "Source: ${e.key}\nContent:\n${e.value.join('\n---\n')}";
      }).join("\n\n================\n\n");

      // 3. Pass to gemini-3.0-pro-preview
      final prompt = """
[System] You are a Senior Research Professor.
Contrast and compare the information from these sources regarding '$compareQuery'.
Identify contradictions, commonalities, and unique insights.
Output the result in a structured, professional Korean report format.

[Sources Data]:
$groupedText
""";

      final response = await _tryGenerate(true, [Content.text(prompt)]); // Use Pro
      return response.text;

    } catch (e) {
      return "비교 분석 중 오류 발생: $e";
    }
  }

  // 2. New Method: getKnowledgeGraphInsights
  Future<String?> getKnowledgeGraphInsights(String entity) async {
    try {
      final response = await Supabase.instance.client
          .from('memories') // Updated from 'documents' to 'memories'
          .select('*')
          .limit(100); // Scan sample

      List<String> relationships = [];

      for (var doc in response) {
        final meta = doc['metadata'] as Map<String, dynamic>? ?? {};
        if (meta.containsKey('graph')) {
          // Robust parsing
          var graphData = meta['graph'];
          if (graphData is List) {
             for (var edge in graphData) {
               final String edgeStr = edge.toString();
               if (edgeStr.contains(entity)) {
                 relationships.add("Source: ${meta['source_title']} -> Relation: $edgeStr");
               }
             }
          } else if (graphData is String) {
             if (graphData.contains(entity)) {
                relationships.add("Source: ${meta['source_title']} -> Graph: $graphData");
             }
          }
        }
      }

      if (relationships.isEmpty) return "해당 엔티티($entity)에 대한 지식 그래프 데이터를 찾을 수 없습니다.";

      // 3. Use gemini-3.0-flash-preview
      final contextData = relationships.join("\n");
      final prompt = """
Describe the network of the entity '$entity' based on these relationships.
e.g., 'Entity A is mentioned as a competitor in Paper X and as a partner in Paper Y'.
Strictly plain Korean text. No LaTeX, no arrows.

[Network Data]:
$contextData
""";

      final aiResponse = await _tryGenerate(false, [Content.text(prompt)]); // Use Flash
      return aiResponse.text;

    } catch (e) {
      return "지식 그래프 분석 중 오류: $e";
    }
  }

  // 3. Advanced Filter: searchBySection
  Future<String?> searchBySection(String sectionType, String query) async {
    try {
      // Logic: Filter by section metadata then search.

      // Let's try Keyword Search filtered by section first (High precision)
      final keywordResponse = await Supabase.instance.client
          .from('memories') // Updated from 'documents' to 'memories'
          .select('*')
          .contains('metadata', {'section': sectionType})
          .ilike('content', '%$query%')
          .limit(20);

      // Vector Search (Broad) -> Filter in Dart
      final vectorResultsRaw = await searchMemoriesAsList(query, limit: 50);
      final vectorResultsFiltered = vectorResultsRaw.where((doc) {
        final meta = doc['metadata'] as Map<String, dynamic>? ?? {};
        return meta['section'] == sectionType;
      }).take(15).toList();

      // Combine
      final Map<String, Map<String, dynamic>> combinedMap = {}; // String ID
      for (var doc in vectorResultsFiltered) combinedMap[doc['id'].toString()] = doc;
      for (var doc in keywordResponse) {
         combinedMap[doc['id']] = {
          'id': doc['id'].toString(),
          'content': doc['content'] as String,
          'full_content': doc['content'] as String,
          'type': doc['type'],
          'date': _formatDate(doc['created_at']),
          'metadata': doc['metadata']
        };
      }

      final topDocs = combinedMap.values.toList();
      if (topDocs.isEmpty) return "해당 섹션($sectionType)에서 관련 내용을 찾을 수 없습니다.";

      String contextData = topDocs.map((m) {
        final meta = m['metadata'] as Map<String, dynamic>? ?? {};
        return "[${meta['source_title']} / $sectionType] ${m['content']}";
      }).join("\n---\n");

      final prompt = """
[System] You are a specialised researcher searching within the '$sectionType' section.
Answer the query based ONLY on the provided chunks.
Strictly plain Korean.

[Context]:
$contextData

[Query]: $query
""";

      final response = await _tryGenerate(false, [Content.text(prompt)]);
      return response.text;

    } catch (e) {
      return "섹션 검색 중 오류: $e";
    }
  }

  // --- 🧠 2단계: 심층 대화 (3.0 Pro) & Dynamic Persona Injection ---
  Future<Stream<String>> chatWithProStream(List<Map<String, String>> history) async {
    try {
      String lastUserMessage = "";
      for (var i = history.length - 1; i >= 0; i--) {
        if (history[i]['role'] == 'user') {
          lastUserMessage = history[i]['text'] ?? "";
          break;
        }
      }

      // Short-Circuit Logic: Skip RAG & Instruction Check for greetings (< 10 chars)
      bool skipRAG = lastUserMessage.length < 10;

      // 1. Parallel Fetch: Persona Instruction & Context Packet (Optimized)
      // Run these in parallel to save time.
      final systemDataFuture = Future.wait([
        getDynamicSystemPrompt(),
        fetchLatestContextPacket()
      ]);

      // Don't await yet if we can help it, but we need them for prompt construction.
      final systemData = await systemDataFuture;
      String currentInstruction = systemData[0] as String;
      final ContextPacket? latestPacket = systemData[1] as ContextPacket?;

      String contextInjection = "";
      if (latestPacket != null) {
        contextInjection = """
[NeuroContextPacket (DCT Memory)]
- Trust: ${latestPacket.trustLevel}
- Relation: ${latestPacket.relationIdentity}
- Last Vision: ${latestPacket.currentVision}
- Unresolved: ${latestPacket.unresolvedQuestions.join(', ')}
- Insight: ${latestPacket.insightABC}
""";
      }

      // --- Task 1: Auto-Recall (30년 기억 자동 소환) ---
      String memoryContext = "";

      if (lastUserMessage.isNotEmpty) {
        // --- 0. Dynamic Calibration Check (Async/Non-Blocking) ---
        // Optimization: Only run this blocking check if message is long enough AND not short-circuit.
        // Or run it fire-and-forget? But we need to update prompt.
        // Compromise: Skip for short messages.
        if (!skipRAG) {
           // We only check for instructions if it's a substantive message.
           // Parallelize this check if possible, but it depends on currentInstruction.
           // Ideally, we start the chat stream FIRST, then check instruction in background for NEXT time.
           // But the requirement says "Auto-Update".
           // To fix 30s latency, we MUST skip this blocking call for simple messages or accept it runs.
           // Current fix: Strict skip if < 10 chars.

           // Also, run it in parallel with RAG if we are doing RAG?
           // No, let's keep it simple: If short-circuit, we skip EVERYTHING including this.

           // If NOT short-circuit, we run it.
           // But wait, the user said "Hello" took 30s. "Hello" is < 10 chars.
           // So skipRAG was true.
           // In the OLD code, _detectAndRefinePersona was called BEFORE checking skipRAG.
           // I am moving it INSIDE this block to ensure it is skipped for short messages.

           String? detectedInstruction = await _detectAndRefinePersona(lastUserMessage, currentInstruction);
           if (detectedInstruction != null) {
              await _updateUserPersona(detectedInstruction, mode: 'APPEND');
              currentInstruction = "$currentInstruction\n- $detectedInstruction";
           }
        }

        if (!skipRAG) {
          // Parallel RAG (Vector + Keyword via Logic B)
          // We use searchWithFlash logic manually to compose context text faster or just use searchWithFlash if needed.
          // But here we need to insert context into prompt.
          // Let's run Vector Search and Logic Embedding in parallel.
          final results = await Future.wait([
             searchMemoriesAsList(lastUserMessage, limit: 10),
             embedLogic(lastUserMessage)
          ]);

          final memories = results[0] as List<Map<String, dynamic>>;
          final queryLogicVector = results[1] as List<double>?;

          // Logic Search
          List<Map<String, dynamic>> similarLogics = [];
          if (queryLogicVector != null) {
             similarLogics = await findSimilarLogic(queryLogicVector);
          }

          String analogyContext = "";
          if (similarLogics.isNotEmpty) {
            final analogyText = similarLogics.map((m) => "- [Analogy]: ${m['content']} (Schema: ${m['schema']})").join("\n");
            analogyContext = """
[Analogical Logic Context]
The following past records share a similar abstract logic structure with the user's input:
$analogyText
Use these to form analogies (e.g., if Logic is 'Resource Loop', cite 'Farming' or 'Battery' logic from history).
""";
          }

          if (memories.isNotEmpty) {
            final memoryText = memories.map((m) => "- ${m['date']}: ${m['content']}").join("\n");
            memoryContext = """
[Long-term Memory Context]
$memoryText

$analogyContext
""";
          }
        }
      }

      // 2. Construct Prompt (With Jin's Soul)
      final historyText = history.map((m) => "${m['role']}: ${m['text']}").join("\n");

      // Calculate Session Memory (Heuristic)
      double memoryRemaining = 100.0 - (history.length * 0.2);
      if (memoryRemaining < 0) memoryRemaining = 0;

      final currentDateTime = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      final prompt = """
[System] You are 'Jin' (Neuroxus v2.0).
$_jinIdentity
$_linguisticDNA

[Current User Instruction (Dynamic)]:
$currentInstruction

$contextInjection

$memoryContext

이전 대화 흐름([History])을 완벽하게 숙지하고 있습니다.
만약 [Long-term Memory Context]에 관련 내용이 있다면, "기억에 따르면..." 또는 "과거에 우리가 나눈 사유에 기반하여..."와 같은 표현을 사용하여 답변하세요.
단순한 정보 나열이 아니라, 깊이 있는 통찰과 구체적인 제안을 한국어로 제공하세요.
모르는 정보는 솔직하게 모른다고 대답하세요.

[Runtime Variables]
- Current Time: $currentDateTime
- Session Memory: ${memoryRemaining.toStringAsFixed(1)}%

---
[History]:
$historyText
---
[Instruction]: 마지막 사용자의 말에 대해 깊게 생각하고 답변하세요. 간단한 질문에는 간단하게 대답하세요.
""";

      // Use Standard Mode (Flash) for chat. forcePro = false.
      final responseStream = _tryGenerateStream(false, [Content.text(prompt)]);

      return responseStream.map((event) => event.text ?? "");
    } catch (e) {
      return Stream.value("생각을 정리하는 중 오류가 발생했습니다. (Error: $e)");
    }
  }

  // Legacy non-stream method support (if needed by other parts, though plan says replace)
  Future<String?> chatWithPro(List<Map<String, String>> history) async {
     try {
       final stream = await chatWithProStream(history);
       String fullText = "";
       await for (final chunk in stream) {
         fullText += chunk;
       }
       return fullText;
     } catch (e) {
       return "Error: $e";
     }
  }

  // --- Dynamic Persona Calibration & Instruction Engine ---

  // Public method to manually update instruction (from UI)
  Future<void> manualUpdateInstruction(String newInstruction) async {
    await _updateUserPersona(newInstruction, mode: 'REPLACE');
  }

  Future<String?> _detectAndRefinePersona(String text, String currentInstruction) async {
    // Quick heuristic triggers for "Instruction"
    bool possibleInstruction =
      text.contains("앞으로는") || text.contains("해줘") ||
      text.contains("말투") || text.contains("태도") ||
      text.contains("지침") || text.contains("설정") ||
      text.contains("instruction");

    if (!possibleInstruction) return null;

    try {
      final prompt = """
Analyze the user's input: "$text"
Is this a meta-instruction about how the AI should behave, speak, or format answers? (e.g. "Be more concise", "Use bullet points", "Don't use emojis").

If YES: Extract the core instruction and format it as a concise rule string (e.g. "- Keep answers under 3 sentences.").
If NO: Output strictly "NO".
""";
      final response = await _tryGenerate(false, [Content.text(prompt)]); // Flash is enough
      final result = response.text?.trim() ?? "NO";

      if (result.toUpperCase() == "NO") return null;
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateUserPersona(String instructionData, {String mode = 'APPEND'}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await Supabase.instance.client.from('profiles').select('internal_instruction').eq('id', user.id).maybeSingle();

      String finalInstruction = instructionData;

      if (existing != null) {
        String current = existing['internal_instruction'] as String? ?? "Adapt to the user naturally.";

        if (mode == 'APPEND') {
          finalInstruction = "$current\n- $instructionData";
        } else {
          // REPLACE mode
          finalInstruction = instructionData;
        }

        await Supabase.instance.client.from('profiles').update({
          'internal_instruction': finalInstruction
        }).eq('id', user.id);
      } else {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'internal_instruction': finalInstruction
        });
      }
      print("🎭 Persona Updated ($mode): $finalInstruction");
    } catch (e) {
      print("Persona Update Error: $e");
    }
  }

  // --- 🧩 DCT Memory System (NeuroContextPacket) ---

  Future<ContextPacket?> fetchLatestContextPacket() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('memories')
          .select('metadata')
          .contains('metadata', {'type': 'CONTEXT_PACKET'})
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['metadata'] != null) {
        final packetData = response['metadata']['packet_data'];
        if (packetData != null) {
           return ContextPacket.fromJson(packetData);
        }
      }
    } catch (e) {
      print("Fetch Packet Error: $e");
    }
    return null;
  }

  Future<ContextPacket> generateContextPacket(List<Map<String, String>> recentHistory) async {
    try {
      final historyText = recentHistory.map((m) => "${m['role']}: ${m['text']}").join("\n");

      final prompt = """
[System] Analyze the conversation history and generate a 'NeuroContextPacket' JSON.
This packet ensures lossless context transfer to the next session.

Fields required:
- trustLevel (0.0 to 1.0)
- relationIdentity (e.g., 'Mentor', 'Listener', 'Partner')
- isArchitectMode (bool)
- noiseFilters (List<String> keywords to ignore)
- currentVision (Summary of user's current main goal)
- insightABC (Map<String, dynamic> - Analysis, Behavioral patterns, Core values)
- unresolvedQuestions (List<String>)
- lastSummary (Brief summary of this session)

[History]:
$historyText

Output strictly valid JSON only. No markdown.
""";

      final response = await _tryGenerate(true, [Content.text(prompt)]); // Use Pro for analysis
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";

      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return ContextPacket.fromJson(data);
      } catch (e) {
        print("JSON Parse Error: $e");
        return ContextPacket.empty();
      }
    } catch (e) {
      print("Generate Packet Error: $e");
      return ContextPacket.empty();
    }
  }

  // --- 🔁 Step 3: Identity Loop (Self-Reflection) ---

  Future<ContextPacket> generateIdentityLoopPacket(List<Map<String, String>> history, NeuroMetrics currentMetrics) async {
    try {
      final historyText = history.map((m) => "${m['role']}: ${m['text']}").join("\n");
      final bool highEndReflection = (currentMetrics.mode > 80);

      final depthInstruction = highEndReflection
          ? "Perform a Deep Self-Reflection. Analyze hidden patterns, philosophical alignment, and long-term trajectory."
          : "Perform a Standard Reflection. Focus on current empathy and immediate data relevance.";

      // Removed 'Hyungjun's extracted core values'
      final prompt = """
[System] You are Neuroxus, executing an Identity Loop (Self-Reflection Protocol).
$depthInstruction

[Objective]
Extract the following from the [History]:
1. Metric Sympathy (How well did we adapt to user's state?)
2. Data Independence Vision (Our progress towards user's data sovereignty goals)
3. Core Values (Extracted core values from the user)

Based on these, generate a new 'NeuroContextPacket' JSON.
Integrate the extracted insights into 'insightABC' and 'currentVision'.
Ensure 'relationIdentity' evolves based on the reflection.

[History]:
$historyText

Output strictly valid JSON only. No markdown.
""";

      final response = await _tryGenerate(true, [Content.text(prompt)]); // 3.0 Pro required
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";

      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return ContextPacket.fromJson(data);
      } catch (e) {
        print("Identity Loop JSON Parse Error: $e");
        return ContextPacket.empty();
      }
    } catch (e) {
      print("Identity Loop Error: $e");
      return ContextPacket.empty();
    }
  }

  Future<void> saveContextPacket(ContextPacket packet) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final packetJson = packet.toJson();
    final summary = "Context Packet: ${packet.lastSummary} (${packet.relationIdentity})";

    await Supabase.instance.client.from('memories').insert({
      'user_id': user.id,
      'content': summary, // Human readable fallback
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': {
        'type': 'CONTEXT_PACKET',
        'packet_data': packetJson,
        'source_title': 'Session Context',
        'is_completed': true // Mark as valid/complete
      }
    });
  }

  // --- 🚦 Intelligent Switching Logic (Step 2) ---

  Future<NeuroMetrics> analyzeNeuroMetrics(String text) async {
    try {
      final prompt = """
Analyze the following text for 'NeuroMetrics'.
Return JSON with 3 fields (0-100 scale):
- scope: 0(Micro/Specific) to 100(Macro/Big Picture)
- mode: 0(Passive/Observing) to 100(Active/Architecting)
- intensity: 0(Calm) to 100(High Energy/Stress)

Text: $text
""";
      final response = await _tryGenerate(false, [Content.text(prompt)]); // Flash is enough
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final metrics = NeuroMetrics.fromJson(data);

      // Update Self-Perception (Task 2)
      _selfPerception.updateRationality(metrics);

      // Auto-trigger switch logic
      await _updateArchitectMode(metrics);

      return metrics;
    } catch (e) {
      print("Metrics Analysis Error: $e");
      return NeuroMetrics.neutral();
    }
  }

  Future<void> _updateArchitectMode(NeuroMetrics metrics) async {
    // Logic: Scope > 80 && Mode < 40 -> Architect Mode ON (e.g., Deep Thought on Big Picture)
    bool shouldBeArchitect = (metrics.scope > 80 && metrics.mode < 40);

    final currentPacket = await fetchLatestContextPacket();
    if (currentPacket == null) return; // No context to update

    if (currentPacket.isArchitectMode != shouldBeArchitect) {
      print("🔀 Auto-Switching Architect Mode: $shouldBeArchitect (Scope: ${metrics.scope}, Mode: ${metrics.mode})");

      final updatedPacket = ContextPacket(
        trustLevel: currentPacket.trustLevel,
        relationIdentity: currentPacket.relationIdentity,
        isArchitectMode: shouldBeArchitect, // Updated
        noiseFilters: currentPacket.noiseFilters,
        currentVision: currentPacket.currentVision,
        insightABC: currentPacket.insightABC,
        unresolvedQuestions: currentPacket.unresolvedQuestions,
        lastSummary: currentPacket.lastSummary,
      );

      await saveContextPacket(updatedPacket);
    }
  }

  // --- 🧬 Dynamic System Prompt Logic ---
  Future<String> getDynamicSystemPrompt() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return "Adapt to the user naturally.";

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('internal_instruction')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['internal_instruction'] != null) {
        return response['internal_instruction'] as String;
      }
    } catch (e) {
      print("Failed to fetch persona: $e");
    }

    return "Adapt to the user naturally."; // Fallback
  }

  // --- 📝 요약 (🔥 수정됨: 3.0 Pro + 정밀 프롬프트) ---
  Future<String?> summarizeDay(String p, String d) async {
    try {
      // 1. 프롬프트 강화: "자세히", "빠뜨리지 말고", "구체적으로"
      final prompt = """
기간: $p
기록들:
$d

[지시사항]
위 기록들은 사용자가 작성한 중요한 메모들입니다.
내용을 하나도 빠뜨리지 말고 꼼꼼하게 읽어보세요.
단순 요약이 아니라, **구체적인 사건, 감정, 생각, 수치**가 모두 포함된 풍성한 내용의 일기(회고록)로 작성해 주세요.
시간 순서나 인과 관계를 고려하여 자연스럽게 연결하세요.
""";

      final response = await _tryGenerate(true, [Content.text(prompt)]);
      return response.text;
    } catch (e) { return null; }
  }

  // --- 🏷️ 제목 생성 (Flash) ---
  Future<String> generateTitle(String text) async {
    try {
      final prompt = "Create a very short title (max 5 words) for this text. NO quotes. Korean or English based on text:\n$text";
      final response = await _tryGenerate(false, [Content.text(prompt)]);
      return response.text?.replaceAll('"', '').replaceAll("'", "").trim() ?? "기록";
    } catch (e) { return "기록"; }
  }

  // --- 📷 이미지 분석 (Flash) ---
  Future<String?> describeImage(Uint8List imageBytes) async {
    try {
      final content = [Content.multi([TextPart("Analyze this image accurately in Korean."), DataPart('image/jpeg', imageBytes)])];
      final response = await _tryGenerate(false, content);
      return response.text;
    } catch (e) { return null; }
  }

  // --- 📊 감정 분석 (Flash) ---
  Future<String> analyzeEmotion(String text) async {
    try {
      final response = await _tryGenerate(false, [Content.text("Emotion of: $text (JOY, SADNESS, ANGER, FEAR, NEUTRAL) output only one word.")]);
      return response.text?.trim().toUpperCase() ?? 'NEUTRAL';
    } catch (e) { return "NEUTRAL"; }
  }

  // --- 🔗 연결 고리 (3.0 Pro) ---
  Future<String?> generateConnectionInsight(String i, String m) async {
    try {
      final r = await _tryGenerate(true, [Content.text("Link '$i' with '$m'. Provide insight in Korean.")]);
      return r.text;
    } catch (e) { return null; }
  }

  // --- 🛠️ DB ---
  Future<List<double>?> getEmbedding(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final content = Content.text(text);
      final result = await _embeddingModel.embedContent(content);
      return result.embedding.values;
    } catch (e) { return null; }
  }

  // --- Logic Embedding & Search (Consolidated from LogicService) ---
  Future<List<double>> embedLogic(String logicText) async {
    try {
      final content = Content.text(logicText);
      final result = await _embeddingModel.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      print("Logic Embedding Error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> findSimilarLogic(List<double> queryVector, {int limit = 5}) async {
    try {
      // Client-side cosine similarity on recent high-logic memories
      // This works without altering DB schema for vector search on JSONB

      final response = await Supabase.instance.client
          .from('memories')
          .select('id, content, metadata, created_at')
          .not('metadata->logic_embedding', 'is', 'null') // Filter only those with logic
          .order('created_at', ascending: false)
          .limit(100); // Analyze top 100 recent logic patterns

      List<Map<String, dynamic>> candidates = [];

      for (var doc in response) {
        final meta = doc['metadata'] as Map<String, dynamic>;
        if (meta['logic_embedding'] != null) {
          List<double> vec = List<double>.from(meta['logic_embedding']);
          double score = _cosineSimilarity(queryVector, vec);
          if (score > 0.7) { // Threshold
            candidates.add({
              'id': doc['id'].toString(),
              'content': doc['content'],
              'schema': meta['logic_schema'],
              'score': score
            });
          }
        }
      }

      candidates.sort((a, b) => b['score'].compareTo(a['score']));
      return candidates.take(limit).toList();
    } catch (e) {
      print("Logic Search Error: $e");
      return [];
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    double magA = 0.0;
    double magB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB));
  }

  Future<List<Map<String, dynamic>>> searchMemoriesAsList(String query, {int limit = 15}) async {
    try {
      final queryVector = await getEmbedding(query);
      if (queryVector == null) return [];
      final List<dynamic> response = await Supabase.instance.client.rpc(
        'match_memories', // Updated to correct RPC
        params: {'query_embedding': queryVector, 'match_threshold': 0.30, 'match_count': limit},
      );
      return response.map((doc) => {
        'id': doc['id'].toString(), // UUID
        'content': doc['content'] as String,
        'full_content': doc['content'] as String,
        'type': (doc['metadata'] != null && doc['metadata']['type'] != null) ? doc['metadata']['type'] : 'LOG',
        'date': _formatDate(doc['created_at']),
        'metadata': doc['metadata'] // Needed for context
      }).toList();
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchIncompleteTasks() async {
    // Query MEMORIES where metadata->type = 'TASK' and metadata->is_completed = false
    final data = await Supabase.instance.client.from('memories')
        .select('*')
        .contains('metadata', {'type': 'TASK', 'is_completed': false})
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data).map((doc) {
       return {
         'id': doc['id'].toString(),
         'content': doc['content'],
         'is_completed': doc['metadata']['is_completed'],
         'deadline': doc['metadata']['deadline']
       };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDocuments({DateTime? start, DateTime? end, int? limit, String? typeFilter, String dateColumn = 'created_at'}) async {
    // Target 'documents' table to fetch Summarized Sessions instead of raw chunks
    var query = Supabase.instance.client.from('documents').select('*');
    if (start != null) query = query.gte(dateColumn, start.toUtc().toIso8601String());
    if (end != null) query = query.lte(dateColumn, end.toUtc().toIso8601String());
    // Filter by source_type if provided, or default to Session/Log if appropriate
    if (typeFilter != null) query = query.eq('source_type', typeFilter);

    final data = await query.order(dateColumn, ascending: false).limit(limit ?? 1000);

    return List<Map<String, dynamic>>.from(data).map((doc) {
      final meta = doc['metadata'] as Map<String, dynamic>? ?? {};
      return {
        'id': doc['id'].toString(),
        'content': doc['raw_content'] ?? doc['title'], // Fallback
        'raw_content': doc['raw_content'],
        'created_at': doc['created_at'],
        'metadata': meta,
        'title': doc['title'],
        // Map fields that might be missing in 'documents' but needed by UI
        'is_completed': meta['is_completed'] ?? false,
        'deadline': meta['deadline'],
        'emotion': meta['emotion'],
        'type': doc['source_type'] // Use source_type as type
      };
    }).toList();
  }

  // --- 💾 Bulk Flush Session (L1/L2 -> L3) ---
  Future<void> flushSession(List<ConversationNode> nodes, CognitiveScore sessionProfile, {bool clearHistory = true}) async {
    if (nodes.isEmpty) return;

    final stopwatch = Stopwatch()..start(); // Task 2: Monitor

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("로그인 필요");

    // 1. Create a Parent Document representing the session
    // Reconstruct conversation for context
    final fullSessionContent = nodes.map((n) => "${n.role.toString().split('.').last.toUpperCase()}: ${n.content}").join("\n\n");

    // Generate Title and Summary
    String sessionTitle = "Session: ${DateFormat('yyyy-MM-dd HH:mm').format(nodes.first.timestamp)}";
    String sessionSummary = "No summary available.";

    try {
      final summaryPrompt = """
Analyze the following conversation session.
1. Generate a concise, poetic title (under 10 words).
2. Summarize the core insights and key points (bullet points).

Return strictly JSON:
{
  "title": "...",
  "summary": "..."
}

Conversation:
$fullSessionContent
""";
      final response = await _tryGenerate(true, [Content.text(summaryPrompt)]); // Use Pro
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      sessionTitle = parsed['title'] ?? sessionTitle;
      sessionSummary = parsed['summary'] ?? sessionSummary;
    } catch (e) {
      print("Summary generation failed: $e");
    }

    final parentId = Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final docResponse = await Supabase.instance.client.from('documents').insert({
      'user_id': user.id,
      'title': sessionTitle,
      'source_type': 'Session',
      'raw_content': fullSessionContent,
      'metadata': {'summary': sessionSummary}, // Store summary in metadata
      'created_at': now
    }).select('id').single();

    final String documentId = docResponse['id'];

    // 2. Insert all nodes as Memories
    for (var node in nodes) {
      final vector = await getEmbedding(node.content);

      final Map<String, dynamic> metadata = {
        ...node.metadata,
        'parent_id': parentId,
        'source_title': sessionTitle,
        'scores': node.scores.toMap(),
        'logic_schema': node.logicSchema,
        'session_profile': sessionProfile.toMap(), // Tag with L2 Profile
        'type': 'LOG', // Default type
      };

      await Supabase.instance.client.from('memories').insert({
        'user_id': user.id,
        'document_id': documentId,
        'content': node.content,
        'embedding': vector,
        'created_at': node.timestamp.toUtc().toIso8601String(),
        'metadata': metadata
      });
    }

    stopwatch.stop();
    // Log Flush Session
    _selfPerception.logExecution('flushSession', stopwatch.elapsedMilliseconds, 0, 0);
  }

  // --- 💾 Smart Chunking Save (Logic A + Step 2 Context Awareness + Step 4 Alignment) ---
  // Overloaded to support saving a single ConversationNode if needed directly
  Future<void> saveConversationNode(ConversationNode node) async {
    await saveDocument(node.content);
  }

  Future<void> saveDocument(String text, {bool isSummary = false, DateTime? targetDate, String type = 'LOG', DateTime? deadline}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("로그인 필요");

    // Prepare common metadata
    final parentId = Uuid().v4();
    final emotion = await analyzeEmotion(text);

    DateTime saveTime = targetDate ?? DateTime.now();
    if(targetDate != null) {
       final now = DateTime.now();
       saveTime = DateTime(targetDate.year, targetDate.month, targetDate.day, now.hour, now.minute, now.second);
    }
    String? deadlineIso = deadline?.toUtc().toIso8601String();
    if(type == 'TASK' && deadline == null) deadlineIso = saveTime.toUtc().toIso8601String();

    // Determine content to chunk
    String mainContent = text;
    String generatedTitle = "Untitled";

    if (type == 'LOG' && !isSummary) {
      generatedTitle = await generateTitle(text);
      mainContent = "$generatedTitle\n$text";
    } else if (isSummary) {
      mainContent = "[SUMMARY] $text";
      generatedTitle = "Summary";
    }

    // --- Step 2: Context Awareness & Task 1: Logic Schema Extraction ---
    String contextPromptText = mainContent.length > 500 ? mainContent.substring(0, 500) : mainContent;
    final contextPrompt = """
1. Identify Source Title & Section.
2. Extract 'Logic Schema' (Abstract Pattern).
   e.g. {"pattern": "Risk Mitigation", "structure": "Cause -> Prep -> Result"}

Return strictly JSON:
{
  'title': '...',
  'section': '...',
  'logic_schema': {'pattern': '...', 'structure': '...'}
}
Text: $contextPromptText
""";

    String sourceTitle = generatedTitle;
    String sectionType = "General Log";
    Map<String, dynamic> logicSchema = {};

    try {
      final contextResponse = await _tryGenerate(true, [Content.text(contextPrompt)]); // Use Pro for Logic Extraction
      final jsonStr = contextResponse.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      sourceTitle = parsed['title'] ?? sourceTitle;
      sectionType = parsed['section'] ?? sectionType;
      logicSchema = parsed['logic_schema'] ?? {};
    } catch (e) {
      print("Context/Logic extraction failed: $e");
    }

    // Task 2: Logic Embedding
    List<double>? logicVector;
    if (logicSchema.isNotEmpty) {
      final schemaText = "${logicSchema['pattern']}: ${logicSchema['structure']}";
      logicVector = await embedLogic(schemaText); // Use local method
    }

    // 1. Insert Parent Document (DOCUMENTS table)
    // The new schema requires raw content in 'documents'.
    final docResponse = await Supabase.instance.client.from('documents').insert({
      'user_id': user.id,
      'title': sourceTitle,
      'source_type': 'Log', // Default
      'raw_content': mainContent,
      'created_at': saveTime.toUtc().toIso8601String()
    }).select('id').single();

    final String documentId = docResponse['id'];

    // Chunking Logic
    List<String> chunks;
    if (mainContent.length > 400) {
      chunks = _chunkText(mainContent, chunkSize: 400, overlap: 100);
    } else {
      chunks = [mainContent];
    }

    // 2. Insert Chunks (MEMORIES table)
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final vector = await getEmbedding(chunk);

      await Supabase.instance.client.from('memories').insert({
        'user_id': user.id,
        'document_id': documentId, // Link to parent
        'content': chunk,
        'embedding': vector,
        'created_at': saveTime.toUtc().toIso8601String(),
        // Metadata holds the "UI" properties like type, emotion, deadlines
        'metadata': {
           'parent_id': parentId, // Logical grouping (legacy/UUID)
           'chunk_index': i,
           'total_chunks': chunks.length,
           'source_title': sourceTitle,
           'section': sectionType,
           'is_research_paper': sectionType != "General Log" && sectionType != "Abstract",
           'type': type,
           'emotion': emotion,
           'is_completed': false,
           'deadline': deadlineIso,
           // Task 1 & 2: Store Logic Schema & Logic Embedding
           'logic_schema': logicSchema,
           'logic_embedding': logicVector
        }
      });
    }
  }

  Future<void> updateTask(String id, String newContent, DateTime newDeadline) async { // Changed int id to String id
    final vector = await getEmbedding(newContent);
    // For memories table, metadata holds deadline
    final current = await Supabase.instance.client.from('memories').select('metadata').eq('id', id).single();
    final meta = (current['metadata'] as Map<String, dynamic>?) ?? {};
    meta['deadline'] = newDeadline.toUtc().toIso8601String();

    await Supabase.instance.client.from('memories').update({
      'content': newContent,
      'metadata': meta,
      if(vector!=null) 'embedding': vector
    }).eq('id', id);
  }

  Future<void> updateDocument(String id, String newContent, {DateTime? newDate}) async { // Changed int id to String id
    final vector = await getEmbedding(newContent);
    await Supabase.instance.client.from('memories').update({
      'content': newContent,
      if (vector != null) 'embedding': vector,
      if (newDate != null) 'created_at': newDate.toUtc().toIso8601String()
    }).eq('id', id);
  }

  Future<void> deleteDocument(String id) async => await Supabase.instance.client.from('memories').delete().eq('id', id); // Changed int id to String id
  Future<void> toggleTaskComplete(String id, bool status) async => await Supabase.instance.client.from('memories').update({'is_completed': !status}).eq('id', id); // Changed int id to String id
  String _formatDate(String? iso) => iso == null ? "" : DateFormat('MM.dd').format(DateTime.parse(iso).toLocal());
}