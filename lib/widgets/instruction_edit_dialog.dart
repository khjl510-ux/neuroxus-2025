
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstructionEditDialog extends StatefulWidget {
  final String currentInstruction;
  final Function(String) onSave;

  const InstructionEditDialog({
    super.key,
    required this.currentInstruction,
    required this.onSave,
  });

  @override
  State<InstructionEditDialog> createState() => _InstructionEditDialogState();
}

class _InstructionEditDialogState extends State<InstructionEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentInstruction);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Personal Instruction",
              style: GoogleFonts.nanumMyeongjo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: "AI에게 바라는 행동 지침을 입력하세요...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                fillColor: const Color(0xFFF5F5F5),
                filled: true,
              ),
              style: GoogleFonts.nanumMyeongjo(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    widget.onSave(_controller.text);
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
