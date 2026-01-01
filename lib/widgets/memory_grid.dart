
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/ai_service.dart';

class MemoryGrid extends StatefulWidget {
  final Function(Map<String, dynamic>) onMemoryTap;
  final String? refreshTrigger; // Token to force refresh (e.g., timestamp)

  const MemoryGrid({super.key, required this.onMemoryTap, this.refreshTrigger});

  @override
  State<MemoryGrid> createState() => _MemoryGridState();
}

class _MemoryGridState extends State<MemoryGrid> {
  final AiService _aiService = AiService();
  Future<Map<String, List<Map<String, dynamic>>>>? _memoryFuture;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _memoryFuture = _fetchMemoriesForDay(_selectedDay!);
  }

  @override
  void didUpdateWidget(MemoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      setState(() {
        _memoryFuture = _fetchMemoriesForDay(_selectedDay!);
      });
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchMemoriesForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    // Fetch specifically for the selected day
    final docs = await _aiService.fetchDocuments(start: startOfDay, end: endOfDay, limit: 100);

    // Even though we fetch for one day, grouping logic remains handy for UI structure
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    String key = DateFormat('MM.dd').format(day);
    if (docs.isNotEmpty) {
       grouped[key] = docs;
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF9F9F9),
      width: MediaQuery.of(context).size.width, // Full Screen Width
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 10),
            child: Row(
              children: [
                Text(
                  "Memory Archive",
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ]
            ),
          ),
          // Calendar Widget
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _memoryFuture = _fetchMemoriesForDay(selectedDay);
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Color(0xFF1B3A57), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: const Color(0xFF1B3A57).withOpacity(0.5), shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _memoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 1));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("기억이 비어있습니다."));
                }

                final groups = snapshot.data!;
                final keys = groups.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final items = groups[key]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(
                            key,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, gridIndex) {
                            final item = items[gridIndex];
                            return GestureDetector(
                              onTap: () {
                                widget.onMemoryTap(item);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))
                                  ],
                                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _extractTitle(item),
                                      style: GoogleFonts.nanumMyeongjo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Text(
                                      _extractTime(item),
                                      style: GoogleFonts.roboto(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
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
    // Prefer the 'title' field if available (added in v1.1)
    if (doc['title'] != null && doc['title'].toString().isNotEmpty && doc['title'] != 'Untitled') {
      return doc['title'];
    }
    // Fallback to content extraction
    final content = doc['content'] as String? ?? "";
    if (content.isEmpty) return "Untitled Memory";
    return content.split('\n').first;
  }

  String _extractTime(Map<String, dynamic> doc) {
    final dateStr = doc['created_at'] as String?;
    if (dateStr == null) return "";
    return DateFormat('HH:mm').format(DateTime.parse(dateStr).toLocal());
  }
}
