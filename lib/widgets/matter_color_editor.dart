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
  bool _applied = false;
  bool _saved = false;

  int get color => _appliedColor;
  bool get isSaved => _saved;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.defaultColor;
    _appliedColor = widget.defaultColor;
  }

  void _apply() {
    setState(() {
      _appliedColor = _selectedColor;
      _applied = true;
      _saved = false;
    });
  }

  void _save() {
    if (!_applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First colour Apply cheyyandi.')),
      );
      return;
    }
    setState(() => _saved = true);
    widget.onSaved(_appliedColor);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          style: TextStyle(color: Color(_appliedColor), fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_saved) setState(() => _saved = false);
          },
        ),
        const SizedBox(height: 8),
        const Text('Title Colour', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) => ChoiceChip(
            label: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
              ),
            ),
            selected: _selectedColor == c,
            onSelected: widget.enabled ? (_) => setState(() {
              _selectedColor = c;
              _applied = false;
              _saved = false;
            }) : null,
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.enabled ? _apply : null,
                child: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.enabled && _applied ? _save : null,
                child: Text(_saved ? 'Saved' : 'Save'),
              ),
            ),
          ],
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
  List<MatterSegment> get segments => List.unmodifiable(_segments);
  bool _internal = false;
  bool _segmentsDirty = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  late String _lastText;
  late int _selectedColor;
  late int _appliedColor;
  bool _colorApplied = false;
  bool _saved = false;

  int get color => _appliedColor;
  bool get isSaved => _saved;

  @override
  void initState() {
    super.initState();
    _segments = _validSegments(widget.initialSegments);
    _selectedColor = widget.defaultColor;
    _appliedColor = widget.defaultColor;
    _lastSelection = widget.controller.selection;
    _lastText = widget.controller.text;
    widget.controller.addListener(_textChanged);
    // Do not commit colour changes until the user explicitly taps Save.
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
      _lastText = widget.controller.text;
      _segmentsDirty = false;
    }
    final incoming = _validSegments(widget.initialSegments);
    final joined = incoming.map((e) => e.text).join();
    final textChanged = widget.controller.text != _lastText;
    if (joined == widget.controller.text &&
        (textChanged || !_segmentsDirty) &&
        incoming.map((e) => e.toMap().toString()).join() !=
            _segments.map((e) => e.toMap().toString()).join()) {
      _segments = incoming;
      _segmentsDirty = false;
    }
    _lastText = widget.controller.text;
  }

  void _textChanged() {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    if (text != _lastText) {
      _lastText = text;
      _lastSelection = selection;
      _segmentsDirty = false;
      _saved = false;
      _colorApplied = false;
    } else if (selection.isValid && selection.start != selection.end) {
      if (selection != _lastSelection) {
        _colorApplied = false;
        _saved = false;
      }
      _lastSelection = selection;
    }
    if (_internal) return;
    final joined = _segments.map((e) => e.text).join();
    if (text != joined) {
      setState(() {
        _segments = text.isEmpty
            ? const []
            : [MatterSegment(text: text, color: widget.defaultColor)];
        _segmentsDirty = false;
      });
    }
  }

  void _applyColor() {
    final selection = _lastSelection.isValid ? _lastSelection : widget.controller.selection;
    if (!selection.isValid || selection.start == selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter lo text select chesi colour Apply cheyyandi.')),
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
      _segmentsDirty = true;
      _appliedColor = _selectedColor;
      _colorApplied = true;
      _saved = false;
    });
  }

  void _save() {
    if (!_colorApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First colour Apply cheyyandi.')),
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
        const Text(
          'Text select → colour Apply → Save. Different portions ki different colours save avutayi.',
          style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Matter Colour', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) => ChoiceChip(
            label: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
              ),
            ),
            selected: _selectedColor == c,
            onSelected: widget.enabled ? (_) => setState(() {
              _selectedColor = c;
              _colorApplied = false;
              _saved = false;
            }) : null,
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.enabled ? _applyColor : null,
                child: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.enabled && _colorApplied ? _save : null,
                child: Text(_saved ? 'Saved' : 'Save'),
              ),
            ),
          ],
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
