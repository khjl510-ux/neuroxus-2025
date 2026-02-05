
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_service.dart';

class MemoryDrawer extends StatefulWidget {
  final Function(Map<String, dynamic>) onMemoryTap;

  const MemoryDrawer({super.key, required this.onMemoryTap});

  @override
  State<MemoryDrawer> createState() => _MemoryDrawerState();
}

class _MemoryDrawerState extends State<MemoryDrawer> {
  final AiService _aiService = AiService();
  Future<Map<String, List<Map<String, dynamic>>>>? _memoryFuture;

  @override
  void initState() {
    super.initState();
    _memoryFuture = _fetchAndGroupMemories();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAndGroupMemories() async {
    // Fetch recent 100 documents for the drawer
    final docs = await _aiService.fetchDocuments(limit: 100);
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var doc in docs) {
      // Safe parsing of created_at
      final dateStr = doc['created_at'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      String key;

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        key = "Today";
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        key = "Yesterday";
      } else {
        key = DateFormat('yyyy. MM. dd').format(date);
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(doc);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Center(
              child: Text(
                "Temporal Archive",
                style: GoogleFonts.nanumMyeongjo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _memoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonLoader();
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No memories found."));
                }

                final groups = snapshot.data!;
                final keys = groups.keys.toList();

                return ListView.builder(
                  itemCount: keys.length,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final items = groups[key]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            key,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...items.map((doc) => ListTile(
                              title: Text(
                                _extractTitle(doc),
                                style: GoogleFonts.nanumMyeongjo(fontSize: 14, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              dense: true,
                              onTap: () {
                                widget.onMemoryTap(doc);
                                Navigator.pop(context);
                              },
                            ))
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _extractTitle(Map<String, dynamic> doc) {
    final content = doc['content'] as String;
    // Try to split by newline and take first line
    final firstLine = content.split('\n').first;
    if (firstLine.length > 30) return "${firstLine.substring(0, 30)}...";
    return firstLine;
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 60, height: 10, color: Colors.grey[200]),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 14, color: Colors.grey[200]),
              const SizedBox(height: 6),
              Container(width: 200, height: 14, color: Colors.grey[200]),
            ],
          ),
        );
      },
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white);
  }
}
