import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart'; // Add permission handling logic
import 'package:uuid/uuid.dart'; // Added for ID generation
import 'memory_space_screen.dart';
import 'glass_input_panel.dart';
import '../services/ai_service.dart'; // Import AiService for saving
import '../widgets/synapse_view.dart'; // Import SynapseView
import '../models/neuro_metrics.dart'; // Import NeuroMetrics
import '../widgets/chat_bubble.dart'; // Import ChatBubble
import '../widgets/memory_grid.dart'; // Import MemoryGrid
import '../widgets/instruction_edit_dialog.dart'; // Import InstructionEditDialog
import '../models/conversation_node.dart'; // Added missing import
import '../models/cognitive_score.dart'; // Added missing import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Phase State
  bool _isAwake = false;

  // Interaction State
  Timer? _longPressTimer;
  int _longPressTickCount = 0;

  // Voice State
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // Service
  final AiService _aiService = AiService();

  // Session State
  late String _currentSessionId; // Unique ID for current session
  bool _isSyncing = false; // Real-time sync indicator
  String _lastArchivedAt = ""; // Trigger for MemoryGrid refresh

  // DCT Memory & Chat State
  final List<Map<String, String>> _conversationHistory = [];
  // Local list for UI rendering (Chat Bubbles)
  final List<Map<String, dynamic>> _chatMessages = [];

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _turnCount = 0;
  Timer? _inactivityTimer;
  NeuroMetrics _currentMetrics = NeuroMetrics.neutral(); // Default state

  // Identity Loop State
  bool _isReflecting = false; // Flag to handle interrupt
  bool _isTyping = false; // AI Typing indicator

  @override
  void initState() {
    super.initState();
    _currentSessionId = const Uuid().v4(); // Generate Session ID on start
    _checkPermissions();
    // Phase 2: The Awakening Trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _triggerAwakening);
    });
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 30), () {
      _triggerContextCheckpoint("Inactivity (30min)", silent: true);
    });
  }

  Future<void> _triggerContextCheckpoint(String reason, {bool silent = false}) async {
    if (_conversationHistory.isEmpty) return;
    if (_isReflecting) return; // Prevent overlapping reflections

    setState(() => _isReflecting = true);

    if (!silent) {
       print("Triggering Identity Loop Checkpoint: $reason");
    } else {
       print("Silently Triggering Identity Loop...");
    }

    try {
      // Step 3: Use generateIdentityLoopPacket
      final packet = await _aiService.generateIdentityLoopPacket(_conversationHistory, _currentMetrics);

      // If user interrupted during generation, abort save
      if (!_isReflecting) {
        print("Identity Loop Aborted by User Input");
        return;
      }

      await _aiService.saveContextPacket(packet);
      if (!silent) {
        print("Identity Loop Completed.");
      }
    } catch (e) {
      print("Identity Loop Failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isReflecting = false);
      }
    }
  }

  void _trackConversation(String role, String text) {
    _conversationHistory.add({'role': role, 'text': text});
    _turnCount++;
    _resetInactivityTimer();

    // Checkpoint every 20 turns
    if (_turnCount % 20 == 0) {
      _triggerContextCheckpoint("Turn Count $_turnCount");
    }
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  void _triggerAwakening() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isAwake = true;
    });
  }

  // --- Voice Logic ---
  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      HapticFeedback.mediumImpact();
      _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
             setState(() => _isListening = false);
             _handleInput(val.recognizedWords);
             HapticFeedback.lightImpact();
          }
        },
      );
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
    HapticFeedback.lightImpact();
  }

  void _handleInput(String text) {
    if (text.trim().isEmpty) return;

    // Interrupt Identity Loop if active
    if (_isReflecting) {
      print("⚠️ Interrupting Identity Loop for User Input");
      setState(() => _isReflecting = false);
    }

    // 1. Optimistic UI Update (Zero Jank)
    setState(() {
      _chatMessages.add({
        'role': 'user',
        'text': text,
        'timestamp': DateTime.now()
      });
      _isTyping = true;
    });
    _scrollToBottom();
    _inputController.clear();

    _trackConversation('user', text);

    // Real-time Logging (Async - Fire & Forget with UI state)
    setState(() => _isSyncing = true);
    _aiService.logChatRealtime(_currentSessionId, 'user', text).whenComplete(() {
      if (mounted) setState(() => _isSyncing = false);
    });

    // 2. Stream Processing (StreamBuilder pattern manually implemented)
    Future.microtask(() async {
      try {
        // Update Metrics (Async - Fire & Forget)
        _aiService.analyzeNeuroMetrics(text).then((metrics) {
           if (mounted) setState(() => _currentMetrics = metrics);
        });

        // Generate AI Response Stream
        // We handle streaming manually to update the *last* chat bubble in place
        final stream = await _aiService.chatWithProStream(_conversationHistory);

        String fullResponse = "";
        bool firstChunk = true;

        await for (final chunk in stream) {
          if (!mounted) break;

          fullResponse += chunk;

          if (firstChunk) {
             // Initialize AI Message Bubble
             setState(() {
               _isTyping = false;
               _chatMessages.add({
                 'role': 'ai',
                 'text': fullResponse, // Start with first chunk
                 'timestamp': DateTime.now()
               });
             });
             firstChunk = false;
          } else {
             // Update Existing Bubble
             setState(() {
                _chatMessages.last['text'] = fullResponse;
             });
          }
          _scrollToBottom();
        }

        // Finalize
        if (mounted) {
           _trackConversation('ai', fullResponse);
           // Real-time Logging for AI (Async)
           if (mounted) setState(() => _isSyncing = true);
           _aiService.logChatRealtime(_currentSessionId, 'ai', fullResponse).whenComplete(() {
             if (mounted) setState(() => _isSyncing = false);
           });
        }

      } catch (e) {
        print("Stream Processing Error: $e");
        if (mounted) setState(() => _isTyping = false);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openInstructionEditor() async {
    // 1. Fetch current instruction
    final current = await _aiService.getDynamicSystemPrompt();

    if (!mounted) return;

    // 2. Show Dialog
    showDialog(
      context: context,
      builder: (context) => InstructionEditDialog(
        currentInstruction: current,
        onSave: (newInstruction) async {
          await _aiService.manualUpdateInstruction(newInstruction);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Personal Instruction Updated", style: GoogleFonts.nanumMyeongjo()))
            );
          }
        },
      ),
    );
  }

  // --- Interaction Logic ---

  void _onTapCore() {
    // Toggle Voice Mode
    if (!_isListening) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _onVerticalDrag(DragUpdateDetails details) {
    // Swipe Up: Restrict trigger area to bottom 30% of Core
    // Core height is roughly width of scale.
    // We can assume local position is relative to the Core widget (180px).
    // Bottom 30% means dy > 180 * 0.7 = 126.

    if (details.localPosition.dy > (180 * 0.7) && details.delta.dy < -5) {
      _openInputPanel();
    }
  }

  void _openInputPanel() {
    HapticFeedback.selectionClick();
    _stopListening(); // Stop voice if active

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Important for Glassmorphism overlay
        pageBuilder: (context, _, __) => const GlassInputPanel(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    ).then((result) {
      if (result != null && result is String && result.isNotEmpty) {
        _handleInput(result);
      } else {
        // Return to Voice Mode Initial State (Auto-start implied by prompt "return to the Initial Voice Mode")
        // "Dismiss keyboard/input bar and return to the Initial Voice Mode."
        // We can optionally restart listening or just idle. Let's idle for now to be less intrusive.
      }
    });
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _longPressTickCount = 0;
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      HapticFeedback.lightImpact(); // Subtle tick
      _longPressTickCount++;
      if (_longPressTickCount >= 5) { // 1.5s approx
        timer.cancel();
        _navigateToMemorySpace();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _longPressTimer?.cancel();
  }

  void _navigateToMemorySpace() {
    HapticFeedback.heavyImpact();
    // ScaleUp and FadeOut logic could be done via Hero or custom transition.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => const MemorySpaceScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // Allow resize for chat input
      drawer: MemoryGrid( // Changed from MemoryDrawer to MemoryGrid
        refreshTrigger: _lastArchivedAt, // Pass trigger to refresh drawer
        onMemoryTap: (doc) {
          // Open Detail View (Core Interaction)
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Date and Title
                  Text(
                    doc['created_at'] != null ? DateFormat('yyyy. MM. dd HH:mm').format(DateTime.parse(doc['created_at']).toLocal()) : 'Memory',
                    style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    doc['title'] ?? 'Untitled Session',
                    style: GoogleFonts.nanumMyeongjo(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                  ),
                  const Divider(height: 30, color: Color(0xFFE0DCD5)),

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Core Summary (if available)
                          if (doc['metadata'] != null && doc['metadata']['summary'] != null) ...[
                            Text(
                              "💡 Core Insights",
                              style: GoogleFonts.nanumMyeongjo(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1B3A57)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F7F1), // Paper color
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE0DCD5)),
                              ),
                              child: Text(
                                doc['metadata']['summary'],
                                style: GoogleFonts.nanumMyeongjo(fontSize: 15, height: 1.6, color: const Color(0xFF1A1A1A)),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Section 2: Original Conversation
                          Text(
                            "📜 Original Conversation",
                            style: GoogleFonts.nanumMyeongjo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            doc['raw_content'] ?? doc['content'] ?? '', // Fallback to content if raw_content missing
                            style: GoogleFonts.nanumMyeongjo(fontSize: 15, height: 1.6, color: const Color(0xFF4A4A4A)),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(builder: (context) => IconButton(
          icon: const Icon(Icons.grid_view, color: Colors.black54), // Grid Icon
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        // "중앙 원 삭제" requirement: Removed SynapseView from center/background logic?
        // Wait, requirement says "중앙 원 삭제, 그리드 아카이브 화면 시공".
        // It implies the persistent large circle might be removed or replaced by the Grid as main view?
        // "제미나이 스타일 UI 구축 ... 메인으로 구축하라."
        // Usually Gemini is Chat-centric.
        // Let's assume "Central Circle" refers to the old HomeScreen design with the big sphere.
        // The current implementation puts SynapseView in the background (opacity 0.15).
        // I will remove the SynapseView background to strictly follow "Delete Central Circle".

        title: _isReflecting
          ? Text("Reflecting...", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: Colors.purple.withOpacity(0.6)))
          : (_isSyncing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text("Syncing...", style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey))
                  ],
                )
              : null),
        centerTitle: true,
        actions: [
          // Manual Save Button (Flush Session)
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.black54),
            tooltip: "현재 대화 저장 (이어하기)",
            onPressed: () {
              // Flush session without clearing history
              Future.microtask(() async {
                await _aiService.flushSession(
                  // We need to construct conversation nodes from _conversationHistory or _chatMessages
                  // Currently _conversationHistory is List<Map<String, String>>
                  // flushSession expects List<ConversationNode>.
                  // We'll create a helper or just map it here.
                  _conversationHistory.map((m) => ConversationNode(
                    id: const Uuid().v4(), // Required unique ID
                    role: m['role'] == 'user' ? Role.user : Role.assistant,
                    content: m['text'] ?? "",
                    timestamp: DateTime.now(), // Approximate
                    scores: CognitiveScore( // Required neutral scores
                      stabilityVsAggressive: 50,
                      logicVsEmotion: 50,
                      overviewVsDetail: 50,
                      consistencyVsOpenness: 50,
                      utilityVsCuriosity: 50,
                      temporalVsPerpetual: 50,
                    ),
                    logicSchema: "Manual Save", // Default schema
                    metadata: {},
                  )).toList(),
                  // Placeholder score for manual save
                  CognitiveScore(
                    stabilityVsAggressive: 0, logicVsEmotion: 0, overviewVsDetail: 0, consistencyVsOpenness: 0, utilityVsCuriosity: 0, temporalVsPerpetual: 0
                  ),
                  _currentSessionId, // Pass Session ID for Upsert
                  clearHistory: false // Keep context!
                );

                if (mounted) {
                  setState(() => _lastArchivedAt = DateTime.now().toIso8601String());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("세션이 저장되었습니다. (보관함 동기화 완료)", style: GoogleFonts.nanumMyeongjo()))
                  );
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: _openInstructionEditor,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Removed SynapseView Background as per "Central Circle Delete" instruction.

          // --- Foreground: Chat UI ---

          // --- Foreground: Chat UI ---
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatMessages.length) {
                      // Typing Indicator
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 20, top: 10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                          ),
                        ),
                      );
                    }
                    final msg = _chatMessages[index];
                    return ChatBubble(
                      text: msg['text'],
                      isUser: msg['role'] == 'user',
                      timestamp: msg['timestamp'],
                    );
                  },
                ),
              ),

              // --- Input Area (Gemini Style) ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.grey),
                        onPressed: _isListening ? _stopListening : _startListening,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: GoogleFonts.nanumMyeongjo(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "무엇을 도와드릴까요?",
                            hintStyle: GoogleFonts.nanumMyeongjo(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: _handleInput,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black87,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                          onPressed: () => _handleInput(_inputController.text),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSphere() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Synapse View for NeuroMetrics
        SynapseView(
          metrics: _currentMetrics, // Pass dynamic metrics
        ),

        ClipRRect(
          borderRadius: BorderRadius.circular(500),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  "N",
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 40,
                    color: const Color(0xFF1A1A1A).withOpacity(0.6),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(
          // Voice Recognition Fix: Auto-start on complete
          onComplete: (controller) {
            if (!_isListening) _startListening();
          }
        )
        .fadeIn(duration: 500.ms)
        .scaleXY(begin: 0.0, end: 1.0, curve: Curves.elasticOut, duration: 1500.ms)
        .shimmer(blendMode: BlendMode.srcOver, color: Colors.white.withOpacity(0.3))
      ],
    );
  }

  List<Widget> _buildRipples() {
    final colors = [
      const Color(0xFFE0F7FA).withOpacity(0.4), // Mint
      const Color(0xFFF3E5F5).withOpacity(0.4), // Lavender
      const Color(0xFFFCE4EC).withOpacity(0.4), // Pink
    ];

    return List.generate(3, (index) {
      return Container(
        width: 100, // Initial small size
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[index],
        ),
      )
      .animate(
        onPlay: (controller) => controller.repeat(),
        delay: (index * 800).ms,
      )
      .scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(10.0, 10.0), // Phase 2: Scale 10.0
        duration: 2500.ms, // Phase 2: 2.5s
        curve: Curves.easeOut,
      )
      .fadeOut(
        duration: 2500.ms,
        curve: Curves.linear,
      );
    });
  }
}
