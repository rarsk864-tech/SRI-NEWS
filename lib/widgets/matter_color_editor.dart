import 'package:flutter/material.dart';
import '../models/news_item.dart';

class TitleColorEditor extends StatefulWidget {
  final List<int> colors;
  final int initialColor;
  final ValueChanged<int>? onSaved;
  final bool enabled;

  const TitleColorEditor({
    super.key,
    required this.colors,
    required this.initialColor,
    this.onSaved,
    this.enabled = true,
  });

  @override
  State<TitleColorEditor> createState() => TitleColorEditorState();
}

class TitleColorEditorState extends State<TitleColorEditor> {
  late int _selectedColor;
  late int _savedColor;
  late int _appliedColor;

  int get savedColor => _savedColor;
  bool get hasUnsavedChanges => _appliedColor != _savedColor;
  bool get needsApply => _selectedColor != _appliedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _savedColor = widget.initialColor;
    _appliedColor = widget.initialColor;
  }

  @override
  void didUpdateWidget(covariant TitleColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialColor != widget.initialColor && !hasUnsavedChanges) {
      _selectedColor = widget.initialColor;
      _savedColor = widget.initialColor;
      _appliedColor = widget.initialColor;
    }
  }

  void _applyColor() {
    setState(() => _appliedColor = _selectedColor);
  }

  void _saveColor() {
    setState(() => _savedColor = _selectedColor);
    widget.onSaved?.call(_savedColor);
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: widget.enabled
                  ? () => setState(() => _selectedColor = c)
                  : null,
              child: Container(
                width: 34,
                height: 34,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled ? _applyColor : null,
                icon: const Icon(Icons.colorize),
                label: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.enabled && hasUnsavedChanges && !needsApply ? _saveColor : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            needsApply
                ? 'Colour selected. Press Apply Colour.'
                : (hasUnsavedChanges ? 'Colour applied. Press Save.' : 'Title colour saved'),
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12),
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
  late List<MatterSegment> _savedSegments;
  late List<MatterSegment> _workingSegments;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  int? _selectedColor;
  bool _internal = false;

  /// Only committed/saved segments are returned to the upload flow.
  List<MatterSegment> get segments => List.unmodifiable(_savedSegments);
  bool get hasUnsavedChanges => !_sameSegments(_savedSegments, _workingSegments);

  @override
  void initState() {
    super.initState();
    final valid = _validSegments(widget.initialSegments);
    _savedSegments = List<MatterSegment>.from(valid);
    _workingSegments = List<MatterSegment>.from(valid);
    _lastSelection = _nonCollapsed(widget.controller.selection)
        ? widget.controller.selection
        : const TextSelection.collapsed(offset: 0);
    widget.controller.addListener(_textChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(List.unmodifiable(_savedSegments));
    });
  }

  bool _nonCollapsed(TextSelection selection) =>
      selection.isValid && selection.start != selection.end;

  bool _sameSegments(List<MatterSegment> a, List<MatterSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].text != b[i].text || a[i].color != b[i].color) return false;
    }
    return true;
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
    }
    final incoming = _validSegments(widget.initialSegments);
    if (!_sameSegments(incoming, _savedSegments) && !hasUnsavedChanges) {
      _savedSegments = List<MatterSegment>.from(incoming);
      _workingSegments = List<MatterSegment>.from(incoming);
    }
  }

  void _textChanged() {
    final selection = widget.controller.selection;
    // IMPORTANT: do not replace the last real selection with a collapsed
    // selection. Android can collapse the selection when the keyboard is
    // hidden. The selected range must still be usable after keyboard close.
    if (_nonCollapsed(selection)) {
      _lastSelection = selection;
    }
    if (_internal) return;

    final text = widget.controller.text;
    final joined = _workingSegments.map((e) => e.text).join();
    if (text != joined) {
      final next = text.isEmpty
          ? const <MatterSegment>[]
          : [MatterSegment(text: text, color: widget.defaultColor)];
      setState(() {
        _savedSegments = List<MatterSegment>.from(next);
        _workingSegments = List<MatterSegment>.from(next);
      });
      widget.onChanged(List.unmodifiable(_savedSegments));
    }
  }

  void _chooseColor(int color) {
    setState(() => _selectedColor = color);
  }

  void _applyColor() {
    final selection = _nonCollapsed(_lastSelection)
        ? _lastSelection
        : (_nonCollapsed(widget.controller.selection)
            ? widget.controller.selection
            : null);

    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matter lo text select chesi colour apply cheyyandi.')),
      );
      return;
    }

    final color = _selectedColor ?? widget.defaultColor;
    final next = applyMatterColorSelection(
      widget.controller.text,
      _workingSegments,
      selection,
      color,
      widget.defaultColor,
    );
    setState(() => _workingSegments = next);
  }

  void _saveColor() {
    if (!hasUnsavedChanges) return;
    setState(() => _savedSegments = List<MatterSegment>.from(_workingSegments));
    widget.onChanged(List.unmodifiable(_savedSegments));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final previewSegments = _workingSegments.isEmpty && text.isNotEmpty
        ? [MatterSegment(text: text, color: widget.defaultColor)]
        : _workingSegments;

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
        if (text.trim().isNotEmpty)
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
                children: previewSegments.map((s) => TextSpan(
                  text: s.text,
                  style: TextStyle(
                    color: Color(s.color),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                )).toList(),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Text('Select Colour', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: widget.colors.map((c) {
            return GestureDetector(
              onTap: widget.enabled ? () => _chooseColor(c) : null,
              onTapDown: widget.enabled
                  ? (_) {
                      final selection = widget.controller.selection;
                      // When keyboard is hidden, the controller can report a
                      // collapsed selection on this tap. Keep the last real
                      // selected range instead of overwriting it.
                      if (_nonCollapsed(selection)) {
                        _lastSelection = selection;
                      }
                    }
                  : null,
              child: Container(
                width: 34,
                height: 34,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled ? _applyColor : null,
                icon: const Icon(Icons.colorize),
                label: const Text('Apply Colour'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.enabled && hasUnsavedChanges && !needsApply ? _saveColor : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            hasUnsavedChanges ? 'Colour applied. Press Save.' : 'Colour saved',
            style: TextStyle(
              color: hasUnsavedChanges ? Colors.orange.shade800 : Colors.green,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
