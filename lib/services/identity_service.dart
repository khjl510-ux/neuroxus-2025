import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';

class IdentityService {
  // TODO: Set your Gemini API Key via --dart-define=GEMINI_API_KEY=...
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY_HERE');
  final String _modelName = 'gemini-3-pro-preview'; // Using Pro for deeper reasoning

  // 1. Extract User Identity from Session Nodes
  Future<String> extractUserIdentity(List<ConversationNode> sessionNodes) async {
    if (sessionNodes.isEmpty) return "No data provided.";

    final model = GenerativeModel(model: _modelName, apiKey: _apiKey);

    // Aggregate content for analysis
    String sessionContent = sessionNodes.map((n) => "- ${n.content}").join("\n");
    if (sessionContent.length > 5000) sessionContent = sessionContent.substring(0, 5000); // Truncate if too long

    final prompt = """
Analyze the following session content to extract the user's identity.
Focus on their decision-making patterns, values, and cognitive style.
Identify "Decision Points" - key sentences that reveal their personality.

[Session Content]
$sessionContent

[Output Requirement]
Write a concise, descriptive profile (1-2 sentences) in Korean.
Example: "이 사용자는 논리적 근거보다 직관적 희열을 중시하는 도전적인 설계자임."
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Identity extraction failed.";
    } catch (e) {
      print("Identity extraction error: $e");
      return "Identity analysis unavailable.";
    }
  }

  // 2. Generate Internal Instruction based on Profile and Scores (Challenge Mode included)
  String updateInternalInstruction(String identityProfile, CognitiveScore sessionProfile) {
    List<String> instructions = [];

    // Base Instruction from Profile
    instructions.add("User Profile: $identityProfile");

    // Analyze Scores for Guidelines
    if (sessionProfile.stabilityVsAggressive < 20) {
      instructions.add("User is highly Risk-Averse. Prioritize safety and stability in all suggestions.");
    } else if (sessionProfile.stabilityVsAggressive > 80) {
      instructions.add("User is Aggressive. Propose bold, high-risk/high-reward options.");
    }

    if (sessionProfile.logicVsEmotion < 20) {
      instructions.add("User is Logic-driven. Use data, charts, and logical arguments.");
    } else if (sessionProfile.logicVsEmotion > 80) {
      instructions.add("User is Emotion-driven. Appeal to intuition, feelings, and narrative.");
    }

    // Challenge Mode Logic (Dynamic Balance)
    // If a score is extreme (<10 or >90), add a directive to challenge it.
    if (sessionProfile.overviewVsDetail < 10) {
      instructions.add("[Challenge Mode] User is too Macro. Intentionally ask for specific details to ground them.");
    } else if (sessionProfile.overviewVsDetail > 90) {
      instructions.add("[Challenge Mode] User is too Micro. Intentionally ask about the big picture to expand their view.");
    }

    if (sessionProfile.consistencyVsOpenness < 10) {
      instructions.add("[Challenge Mode] User is too rigid. Gently introduce novel ideas to encourage openness.");
    }

    // Combine
    return instructions.join("\n");
  }

  // 3. Save Persona to Supabase
  Future<void> savePersona(String identityProfile, String internalInstruction) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'user_identity_description': identityProfile,
        'internal_instruction': internalInstruction,
        'last_updated': DateTime.now().toUtc().toIso8601String(),
      });
      print("Persona updated successfully.");
    } catch (e) {
      print("Failed to save persona: $e");
    }
  }
}
