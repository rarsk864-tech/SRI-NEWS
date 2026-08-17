import 'package:flutter/material.dart';
import '../models/news_item.dart';

class MatterColorEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<int> colors;
  final int defaultColor;
  final List<MatterSegment> initialSegments;
  final ValueChanged<List<MatterSegment>> onChanged;
  final bool enabled;

  const MatterColorEditor({
    super.key,
    required this.controller,
    required this.colors,
    required this.defaultColor,
    required this.initialSegments,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<MatterColorEditor> createState() => _MatterColorEditorState();
}

class _MatterColorEditorState extends State<MatterColorEditor> {
  late List<MatterSegment> _segments;
  bool _internal = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _segments = _validSegments(widget.initialSegments);
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_textChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_segments));
  }

  List<MatterSegment> _validSegments(List<MatterSegment> input) {
    final text = widget.controller.text;
    if (text.isEmpty) return const [];
    final joined = input.map((e) => e.text).join();
    if (joined != text) {
      return [MatterSegment(text: text, color: widget.defaultColor)];
    }
    return input.where((e) => e.text.isNotEmpty).toList();
  }

  void _textChanged() {
    _lastSelection = widget.controller.selection;
    if (_internal) return;
    final text = widget.controller.text;
    final joined = _segments.map((e) => e.text).join();
    if (text != joined) {
      setState(() {
        _segments = text.isEmpty
            ? const []
            : [MatterSegment(text: text, color: widget.defaultColor)];
      });
      widget.onChanged(_segments);
    }
  }

  void _applyColor(int color) {
    final selection = _lastSelection.isValid ? _lastSelection : widget.controller.selection;
    if (!selection.isValid || selection.start == selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter lo text select chesi colour tap cheyyandi.')),
      );
      return;
    }
    final next = applyMatterColorSelection(
      widget.controller.text,
      _segments,
      selection,
      color,
      widget.defaultColor,
    );
    setState(() => _segments = next);
    widget.onChanged(next);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Matter',
            hintText: 'Matter type chesi, colour kavalsina words select cheyyandi',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Text select → colour tap. Different portions ki different colours save avutayi.',
          style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            return GestureDetector(
              // Capture the selection before the colour button takes focus.
              onTapDown: widget.enabled
                  ? (_) => _lastSelection = widget.controller.selection
                  : null,
              onTap: widget.enabled
                  ? () {
                      _lastSelection = widget.controller.selection;
                      _applyColor(c);
                    }
                  : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
            );
          }).toList(),
        ),
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text.rich(
              TextSpan(
                children: _segments.isEmpty
                    ? [TextSpan(text: text, style: TextStyle(color: Color(widget.defaultColor)))]
                    : _segments.map((s) => TextSpan(
                        text: s.text,
                        style: TextStyle(color: Color(s.color), fontSize: 15, height: 1.45, fontWeight: FontWeight.w600),
                      )).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
