// lib/widgets/parent_gate_dialog.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the GROWN-UP CHECK, the parent gate in front of anything a child
/// must not do alone (Apple Guideline 1.3, COPPA): `true` once it is
/// answered, `false` on CANCEL. A tap outside never closes it: an accidental
/// tap just outside the dialog (Jim hit it on the Android emulator) must not
/// silently bail out. [random] deals the problems; tests pass a seeded one.
/// Opened by the onboarding camera page and the bedtime-reminder hand-off.
Future<bool?> showParentGate(BuildContext context, {Random? random}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ParentGateDialog(random: random),
  );
}

/// A typed answer to "A × B" with A in 4..9 and B in 3..7, the same kind of
/// check as the Settings Parent Check. A fixed question with tap targets
/// could be memorised or brute-forced by a child, so a wrong or empty answer
/// clears the field and deals a new problem. Pops `true` on a correct answer
/// and `false` on CANCEL.
class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, this.random});

  /// Deals the problems; a new [Random] when null.
  final Random? random;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _answerController = TextEditingController();
  late final Random _random = widget.random ?? Random();
  late int _mathA;
  late int _mathB;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newProblem();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _newProblem() {
    _mathA = 4 + _random.nextInt(6);
    _mathB = 3 + _random.nextInt(5);
  }

  void _checkAnswer() {
    final answer = int.tryParse(_answerController.text.trim());
    if (answer == _mathA * _mathB) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Try again!';
        _answerController.clear();
        _newProblem();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // The number keypad shrinks the screen: scroll instead of overflowing.
      scrollable: true,
      backgroundColor: const Color(0xFF1A0A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'GROWN-UP CHECK',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type the answer:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            '$_mathA × $_mathB = ?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _answerController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              onSubmitted: (_) => _checkAnswer(),
              decoration: InputDecoration(
                hintText: '?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 24,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF00E5FF),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _checkAnswer,
          child: const Text(
            'CONTINUE',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
