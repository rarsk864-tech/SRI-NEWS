import 'package:flutter/material.dart';
import '../models/news_item.dart';

class TitleColorEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<int> colors;
  final int initialColor;
  final ValueChanged<int> onSaved;
  final VoidCallback? onNext;
  final bool enabled;

  const TitleColorEditor({
    super.key,
    required this.controller,
    required this.colors,
    required this.initialColor,
    required this.onSaved,
    this.onNext,
    this.enabled = true,
  });

  @override
  State<TitleColorEditor> createState() => TitleColorEditorState();
}

class TitleColorEditorState extends State<TitleColorEditor> {
  late int _selectedColor;
  late int _previewColor;
  late int _savedColor;
  bool _applied = false;
  bool _saved = false;
  bool _internal = false;

  bool get isSaved => _saved;
  int get savedColor => _savedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _previewColor = widget.initialColor;
    _savedColor = widget.initialColor;
    widget.controller.addListener(_textChanged);
  }

  void _textChanged() {
    if (_internal) return;
    if (_saved) setState(() => _saved = false);
  }

  void _apply() {
    if (widget.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title type cheyyandi.')),
      );
      return;
    }
    setState(() {
      _previewColor = _selectedColor;
      _applied = true;
      _saved = false;
    });
  }

  void _save() {
    if (!_applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mundhu Apply Colour cheyyandi.')),
      );
      return;
    }
    _savedColor = _previewColor;
    _saved = true;
    widget.onSaved(_savedColor);
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant TitleColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Title Colour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            final selected = _selectedColor == c;
            return GestureDetector(
              onTap: widget.enabled ? () => setState(() => _selectedColor = c) : null,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? Colors.white : Colors.black26, width: selected ? 3 : 1),
                  boxShadow: selected ? const [BoxShadow(color: Colors.black38, blurRadius: 2)] : null,
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title.isEmpty ? 'Title preview' : title,
            style: TextStyle(color: Color(_previewColor), fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled ? _apply : null,
                icon: const Icon(Icons.edit),
                label: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.enabled ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _saved ? 'Title colour Saved' : (_applied ? 'Colour Applied — Save cheyyandi' : 'Colour select → Apply Colour → Save'),
          style: TextStyle(color: _saved ? Colors.green.shade700 : Colors.black54, fontWeight: FontWeight.w700),
        ),
        if (widget.onNext != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.enabled ? widget.onNext : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ),
        ],
      ],
    );
  }
}

class MatterColorEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<int> colors;
  final int defaultColor;
  final List<MatterSegment> initialSegments;
  final ValueChanged<List<MatterSegment>> onChanged;
  final VoidCallback? onNext;
  final bool enabled;

  const MatterColorEditor({
    super.key,
    required this.controller,
    required this.colors,
    required this.defaultColor,
    required this.initialSegments,
    required this.onChanged,
    this.onNext,
    this.enabled = true,
  });

  @override
  State<MatterColorEditor> createState() => MatterColorEditorState();
}

class MatterColorEditorState extends State<MatterColorEditor> {
  late List<MatterSegment> _segments;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  int _selectedColor = 0;
  bool _applied = false;
  bool _saved = false;
  bool _internal = false;

  List<MatterSegment> get segments => List.unmodifiable(_segments);
  bool get isSaved => _saved;

  @override
  void initState() {
    super.initState();
    _segments = _validSegments(widget.initialSegments);
    _selectedColor = widget.defaultColor;
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_textChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_segments));
  }

  List<MatterSegment> _validSegments(List<MatterSegment> input) {
    final text = widget.controller.text;
    if (text.isEmpty) return const [];
    final joined = input.map((e) => e.text).join();
    if (joined != text) return [MatterSegment(text: text, color: widget.defaultColor)];
    return input.where((e) => e.text.isNotEmpty).toList();
  }

  @override
  void didUpdateWidget(covariant MatterColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
      _lastSelection = widget.controller.selection;
    }
  }

  void _textChanged() {
    final selection = widget.controller.selection;
    if (selection.isValid && selection.start != selection.end) _lastSelection = selection;
    if (_internal) return;
    final text = widget.controller.text;
    final joined = _segments.map((e) => e.text).join();
    if (text != joined) {
      setState(() {
        _segments = text.isEmpty ? const [] : [MatterSegment(text: text, color: widget.defaultColor)];
        _saved = false;
        _applied = false;
      });
      widget.onChanged(_segments);
    }
  }

  void _apply() {
    final selection = _lastSelection.isValid ? _lastSelection : widget.controller.selection;
    if (!selection.isValid || selection.start == selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter lo text select chesi colour apply cheyyandi.')),
      );
      return;
    }
    final next = applyMatterColorSelection(
      widget.controller.text,
      _segments,
      selection,
      _selectedColor,
      widget.defaultColor,
    );
    setState(() {
      _segments = next;
      _applied = true;
      _saved = false;
    });
    widget.onChanged(next);
  }

  void _save() {
    if (!_applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mundhu Apply Colour cheyyandi.')),
      );
      return;
    }
    setState(() => _saved = true);
    widget.onChanged(_segments);
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
        const Text('Text select → colour select → Apply Colour → Save.', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            final selected = _selectedColor == c;
            return GestureDetector(
              onTapDown: widget.enabled ? (_) => _lastSelection = widget.controller.selection : null,
              onTap: widget.enabled ? () => setState(() => _selectedColor = c) : null,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? Colors.white : Colors.black26, width: selected ? 3 : 1),
                  boxShadow: selected ? const [BoxShadow(color: Colors.black38, blurRadius: 2)] : null,
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
              ),
            );
          }).toList(),
        ),
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
            child: Text.rich(
              TextSpan(
                children: _segments.isEmpty
                    ? [TextSpan(text: text, style: TextStyle(color: Color(widget.defaultColor)))]
                    : _segments.map((s) => TextSpan(text: s.text, style: TextStyle(color: Color(s.color), fontSize: 15, height: 1.45, fontWeight: FontWeight.w600))).toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: widget.enabled ? _apply : null, icon: const Icon(Icons.edit), label: const Text('Apply Colour'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(onPressed: widget.enabled ? _save : null, icon: const Icon(Icons.save_outlined), label: const Text('Save'))),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _saved ? 'Selected text colour Saved' : (_applied ? 'Colour Applied — Save cheyyandi' : 'Text select → colour select → Apply Colour → Save.'),
          style: TextStyle(color: _saved ? Colors.green.shade700 : Colors.black54, fontWeight: FontWeight.w700),
        ),
        if (widget.onNext != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.enabled ? widget.onNext : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ),
        ],
      ],
    );
  }
}
