import 'package:flutter/material.dart';

class CalculatorDisguise extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final Future<bool> Function(String) verifyPin;

  const CalculatorDisguise({
    super.key,
    required this.onAuthSuccess,
    required this.verifyPin,
  });

  @override
  State<CalculatorDisguise> createState() => _CalculatorDisguiseState();
}

class _CalculatorDisguiseState extends State<CalculatorDisguise> {
  String _display = '0';
  String _equation = '';
  bool _startNewNumber = true;
  bool _hasDecimal = false;

  void _addDigit(String digit) {
    setState(() {
      if (_startNewNumber) {
        _display = digit;
        _startNewNumber = false;
      } else {
        _display = _display + digit;
      }
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _equation = '';
      _startNewNumber = true;
      _hasDecimal = false;
    });
  }

  void _addDecimal() {
    setState(() {
      if (_hasDecimal) return;

      if (_startNewNumber) {
        _display = '0.';
        _startNewNumber = false;
      } else {
        _display = '$_display.';
      }
      _hasDecimal = true;
    });
  }

  void _handleOperator(String operator) {
    setState(() {
      _equation = _display;
      _startNewNumber = true;
      _hasDecimal = false;
    });
  }

  Future<void> _calculate() async {
    // Use verifyPin function for checking PIN securely
    final isCorrect = await widget.verifyPin(_display);
    if (isCorrect) {
      widget.onAuthSuccess();
    } else {
      setState(() {
        _display = _display;
        _startNewNumber = true;
        _hasDecimal = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Display
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _equation,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Calculator buttons
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  buildButtonRow(['C', '±', '%', '÷']),
                  buildButtonRow(['7', '8', '9', '×']),
                  buildButtonRow(['4', '5', '6', '-']),
                  buildButtonRow(['1', '2', '3', '+']),
                  buildButtonRow(['0', '.', 'DEL', '=']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildButtonRow(List<String> buttons) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.map((buttonText) => buildButton(buttonText)).toList(),
      ),
    );
  }

  Widget buildButton(String text) {
    Color bgColor;
    Color textColor;

    // Determine button color based on its function
    if (text == '=') {
      bgColor = Colors.orange;
      textColor = Colors.white;
    } else if (['÷', '×', '-', '+'].contains(text)) {
      bgColor = Colors.orange;
      textColor = Colors.white;
    } else if (['C', '±', '%', 'DEL'].contains(text)) {
      bgColor = Colors.grey.shade800;
      textColor = Colors.white;
    } else {
      bgColor = Colors.grey.shade900;
      textColor = Colors.white;
    }

    void onPressed() {
      if (text == 'C') {
        _clear();
      } else if (text == '=') {
        _calculate();
      } else if (text == '.') {
        _addDecimal();
      } else if (['÷', '×', '-', '+', '%', '±'].contains(text)) {
        _handleOperator(text);
      } else if (text == 'DEL') {
        setState(() {
          if (_display.length > 1) {
            _display = _display.substring(0, _display.length - 1);
          } else {
            _display = '0';
            _startNewNumber = true;
          }
        });
      } else {
        // It's a digit
        _addDigit(text);
      }
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
