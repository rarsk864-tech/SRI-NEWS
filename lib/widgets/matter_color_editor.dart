import 'package:flutter/material.dart';
import '../models/news_item.dart';

class TitleColorEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<int> colors;
  final int defaultColor;
  final ValueChanged<int> onSaved;
  final bool enabled;

  const TitleColorEditor({
    super.key,
    required this.controller,
    required this.colors,
    required this.defaultColor,
    required this.onSaved,
    this.enabled = true,
  });

  @override
  State<TitleColorEditor> createState() => TitleColorEditorState();
}

class TitleColorEditorState extends State<TitleColorEditor> {
  late int _selectedColor;
  late int _appliedColor;
  late int _savedColor;

  bool get isSaved => _savedColor == _appliedColor;
  int get savedColor => _savedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.defaultColor;
    _appliedColor = widget.defaultColor;
    _savedColor = widget.defaultColor;
  }

  void _apply() {
    if (widget.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title type cheyyandi.')),
      );
      return;
    }
    setState(() => _appliedColor = _selectedColor);
  }

  void _save() {
    if (widget.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title type cheyyandi.')),
      );
      return;
    }
    if (_appliedColor != _selectedColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mundhu Apply Colour cheyyandi.')),
      );
      return;
    }
    setState(() => _savedColor = _appliedColor);
    widget.onSaved(_savedColor);
  }

  @override
  Widget build(BuildContext context) {
    final previewColor = Color(_appliedColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Title Colour', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            return GestureDetector(
              onTap: widget.enabled ? () => setState(() => _selectedColor = c) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == c ? Colors.black : Colors.black26,
                    width: _selectedColor == c ? 3 : 1,
                  ),
                ),
                child: _selectedColor == c
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.controller.text.trim().isEmpty ? 'Title preview' : widget.controller.text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: previewColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled ? _apply : null,
                icon: const Icon(Icons.edit),
                label: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.enabled ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isSaved ? 'Title colour Saved' : 'Colour Apply chesi Save cheyyandi.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSaved ? Colors.green : Colors.orange.shade800,
          ),
        ),
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
  State<MatterColorEditor> createState() => MatterColorEditorState();
}

class MatterColorEditorState extends State<MatterColorEditor> {
  late List<MatterSegment> _segments;
  late List<MatterSegment> _savedSegments;
  late int _selectedColor;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  bool _saved = false;

  List<MatterSegment> get segments => List.unmodifiable(_segments);
  List<MatterSegment> get savedSegments => List.unmodifiable(_savedSegments);
  bool get isSaved => _saved;

  @override
  void initState() {
    super.initState();
    _segments = _validSegments(widget.initialSegments);
    _savedSegments = List.of(_segments);
    _selectedColor = widget.defaultColor;
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_textChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_savedSegments));
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

  @override
  void didUpdateWidget(covariant MatterColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
      _lastSelection = widget.controller.selection;
    }
    final incoming = _validSegments(widget.initialSegments);
    final joined = incoming.map((e) => e.text).join();
    if (joined == widget.controller.text &&
        incoming.map((e) => e.toMap().toString()).join() !=
            _segments.map((e) => e.toMap().toString()).join()) {
      _segments = incoming;
      _savedSegments = List.of(incoming);
    }
  }

  void _textChanged() {
    final selection = widget.controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      _lastSelection = selection;
    }
    final text = widget.controller.text;
    final joined = _segments.map((e) => e.text).join();
    if (text != joined) {
      setState(() {
        _segments = text.isEmpty
            ? const []
            : [MatterSegment(text: text, color: widget.defaultColor)];
        _saved = false;
      });
    }
  }

  void _applyColor() {
    final selection = _lastSelection.isValid && _lastSelection.start != _lastSelection.end
        ? _lastSelection
        : widget.controller.selection;
    if (!selection.isValid || selection.start == selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter lo text select chesi Apply Colour tap cheyyandi.')),
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
      _saved = false;
    });
  }

  void _save() {
    if (widget.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter type cheyyandi.')),
      );
      return;
    }
    setState(() {
      _savedSegments = List.of(_segments);
      _saved = true;
    });
    widget.onChanged(_savedSegments);
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
          'Text select → colour select → Apply Colour → Save. Different portions ki repeat cheyyandi.',
          style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Matter Colour', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            return GestureDetector(
              onTapDown: widget.enabled ? (_) => _lastSelection = widget.controller.selection : null,
              onTap: widget.enabled ? () => setState(() => _selectedColor = c) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == c ? Colors.black : Colors.black26,
                    width: _selectedColor == c ? 3 : 1,
                  ),
                ),
                child: _selectedColor == c
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled ? _applyColor : null,
                icon: const Icon(Icons.edit),
                label: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.enabled ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _saved ? 'Selected text colour Saved' : 'Colour Apply chesi Save cheyyandi.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _saved ? Colors.green : Colors.orange.shade800,
          ),
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
