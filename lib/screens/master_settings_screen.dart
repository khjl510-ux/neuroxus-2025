import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';
import '../models/neuro_metrics.dart';
import '../models/conversation_node.dart'; // For Role enum fallback if needed (not used directly here but good for context)

class MasterSettingsScreen extends StatefulWidget {
  final AiService aiService;
  final Function(String) onForceCheckpoint; // Callback to trigger logic in HomeScreen

  const MasterSettingsScreen({super.key, required this.aiService, required this.onForceCheckpoint});

  @override
  State<MasterSettingsScreen> createState() => _MasterSettingsScreenState();
}

class _MasterSettingsScreenState extends State<MasterSettingsScreen> {
  // Section 2: Metrics
  final TextEditingController _metricInputController = TextEditingController();
  NeuroMetrics _currentMetrics = NeuroMetrics.neutral();
  bool _isLoadingMetrics = false;

  // Section 3: Identity
  String _currentPersona = "Loading...";
  bool _isLoadingPersona = false;

  // Section 4: RAG
  final TextEditingController _ragInputController = TextEditingController();
  List<String> _ragResults = [];
  bool _isSearching = false;

  // Section 5: Summary
  final TextEditingController _summaryInputController = TextEditingController();
  String _generatedTitle = "";
  String _generatedSummary = "";
  bool _isSummarizing = false;

  @override
  void initState() {
    super.initState();
    _refreshPersona();
  }

  // --- Actions ---

  Future<void> _analyzeMetrics() async {
    final text = _metricInputController.text;
    if (text.isEmpty) return;
    setState(() => _isLoadingMetrics = true);
    final result = await widget.aiService.analyzeNeuroMetrics(text);
    if (mounted) {
      setState(() {
        _currentMetrics = result;
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _refreshPersona() async {
    setState(() => _isLoadingPersona = true);
    final persona = await widget.aiService.getDynamicSystemPrompt();
    if (mounted) {
      setState(() {
        _currentPersona = persona;
        _isLoadingPersona = false;
      });
    }
  }

  Future<void> _testRAG() async {
    final query = _ragInputController.text;
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await widget.aiService.searchMemoriesAsList(query, limit: 3);
    if (mounted) {
      setState(() {
        _ragResults = results.map((m) => "[${m['date']}] ${m['content']}").toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _testSummary() async {
    final text = _summaryInputController.text;
    if (text.isEmpty) return;
    setState(() => _isSummarizing = true);

    // Simulate what happens in flushSession
    final title = await widget.aiService.generateTitle(text);
    // Note: summarizeDay expects a specific format, but we can test logic roughly
    final summary = await widget.aiService.summarizeDay("Test Day", text);

    if (mounted) {
      setState(() {
        _generatedTitle = title;
        _generatedSummary = summary ?? "Summary Failed";
        _isSummarizing = false;
      });
    }
  }

  // --- UI Helpers ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.nanumMyeongjo(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Master Control Panel", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. Context Checkpoint
          _buildSectionHeader("1. Auto-Context Checkpoint", Icons.save),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Status: Active (Auto-trigger every 20 turns)"),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onForceCheckpoint("Manual Test");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Checkpoint Triggered! Check console logs.")));
                  },
                  icon: const Icon(Icons.flash_on),
                  label: const Text("Force Checkpoint Now"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),

          // 2. NeuroMetrics
          _buildSectionHeader("2. Cognitive Analysis (NeuroMetrics)", Icons.psychology),
          _buildCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _metricInputController, decoration: const InputDecoration(hintText: "Enter text to analyze..."))),
                    IconButton(icon: const Icon(Icons.play_arrow), onPressed: _analyzeMetrics),
                  ],
                ),
                if (_isLoadingMetrics) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                _buildMetricBar("Scope (Micro-Macro)", _currentMetrics.scope),
                _buildMetricBar("Mode (Passive-Active)", _currentMetrics.mode),
                _buildMetricBar("Intensity (Calm-Stress)", _currentMetrics.intensity),
              ],
            ),
          ),

          // 3. Identity & Persona
          _buildSectionHeader("3. Identity Loop (Persona)", Icons.fingerprint),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Current Internal Instruction:", style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshPersona),
                ]),
                if (_isLoadingPersona) const Center(child: CircularProgressIndicator())
                else Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[100],
                  width: double.infinity,
                  height: 100,
                  child: SingleChildScrollView(child: Text(_currentPersona, style: GoogleFonts.roboto(fontSize: 12))),
                ),
              ],
            ),
          ),

          // 4. Vector RAG
          _buildSectionHeader("4. Vector RAG (Memory Search)", Icons.search),
          _buildCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _ragInputController, decoration: const InputDecoration(hintText: "Search query..."))),
                    IconButton(icon: const Icon(Icons.search), onPressed: _testRAG),
                  ],
                ),
                if (_isSearching) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                ..._ragResults.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(r, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                )),
                if (_ragResults.isEmpty && !_isSearching) const Text("No results.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          // 5. Session Summarization
          _buildSectionHeader("5. AI Auto-Summarization", Icons.summarize),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _summaryInputController, maxLines: 3, decoration: const InputDecoration(hintText: "Paste conversation log here to test summary generation...")),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _testSummary, child: const Text("Test Generate"))),
                if (_isSummarizing) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text("Generated Title: $_generatedTitle", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Generated Summary: $_generatedSummary", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12)), Text(value.toStringAsFixed(1))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value / 100, backgroundColor: Colors.grey[200], color: Colors.blueAccent),
        ],
      ),
    );
  }
}
