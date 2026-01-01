import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Glassmorphism Text Input Panel (Floating Bottom Sheet Style)
class GlassInputPanel extends StatefulWidget {
  const GlassInputPanel({super.key});

  @override
  State<GlassInputPanel> createState() => _GlassInputPanelState();
}

class _GlassInputPanelState extends State<GlassInputPanel> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Floating exactly above keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Tap outside to dismiss
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 5) { // Swipe Down
            Navigator.pop(context);
          }
        },
        child: Container(
          color: Colors.transparent, // Hit test for background
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // The Glass Input Bar
              GestureDetector(
                onTap: () {}, // Consume tap
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 20, left: 16, right: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Frosty glass
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                maxLines: null,
                                autofocus: true,
                                style: GoogleFonts.nanumMyeongjo(
                                  fontSize: 18,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: "Enter thought...",
                                  hintStyle: GoogleFonts.nanumMyeongjo(
                                    color: const Color(0xFF1A1A1A).withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                            // Subtle Save Button
                            GestureDetector(
                              onTap: () {
                                if (_textController.text.trim().isNotEmpty) {
                                  Navigator.pop(context, _textController.text);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 2),
                                child: Text(
                                  "Save",
                                  style: GoogleFonts.nanumMyeongjo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1B3A57), // Ink Blue
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
