import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Placeholder for Memory Space Screen
class MemorySpaceScreen extends StatelessWidget {
  const MemorySpaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Memory Space",
          style: GoogleFonts.nanumMyeongjo(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      body: Center(
        child: Text(
          "Memory Space Coming Soon",
          style: GoogleFonts.nanumMyeongjo(
            color: const Color(0xFF8C8C8C),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
