import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ClockDisguise extends StatefulWidget {
  final String correctPin;
  final VoidCallback onAuthSuccess;

  const ClockDisguise({
    super.key,
    required this.correctPin,
    required this.onAuthSuccess,
  });

  @override
  State<ClockDisguise> createState() => _ClockDisguiseState();
}

class _ClockDisguiseState extends State<ClockDisguise>
    with TickerProviderStateMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  int _selectedTab = 0;
  final List<String> _tappedPositions = [];
  List<AlarmClock> _alarms = [];

  @override
  void initState() {
    super.initState();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });

    // Add some default alarms
    _alarms = [
      AlarmClock(
        time: const TimeOfDay(hour: 7, minute: 0),
        isActive: true,
        daysActive: {1, 2, 3, 4, 5},
        label: 'Wake up',
      ),
      AlarmClock(
        time: const TimeOfDay(hour: 8, minute: 30),
        isActive: false,
        daysActive: {1, 3, 5},
        label: 'Go to work',
      ),
    ];
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Check if the sequence of taps matches the PIN
  // For clock disguise, users need to tap positions on the clock face
  // that correspond to their PIN (e.g., for PIN 1234, tap positions at 1, 2, 3, 4 o'clock)
  void _checkPattern() {
    Logger().d('widget.correctPin: ${widget.correctPin}');
    Logger().d('_tappedPositions: $_tappedPositions');
    if (_tappedPositions.length < widget.correctPin.length) return;

    // Get last N taps where N is the length of the PIN
    final List<String> relevantTaps = _tappedPositions
        .sublist(_tappedPositions.length - widget.correctPin.length);

    Logger().d('relevantTaps: $relevantTaps');

    // Check if the sequence matches
    bool matches = true;
    for (int i = 0; i < widget.correctPin.length; i++) {
      final String expectedPosition = 'position_${widget.correctPin[i]}';
      Logger().d('expectedPosition: $expectedPosition');
      Logger().d('relevantTaps[i]: ${relevantTaps[i]}');
      if (relevantTaps[i] != expectedPosition) {
        matches = false;
        break;
      }
    }

    Logger().d('matches: $matches');
    if (matches) {
      widget.onAuthSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clock'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.black87,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildWorldClockTab(),
                  _buildAlarmTab(),
                  _buildStopwatchTab(),
                  _buildTimerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.language),
            label: 'World',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: 'Alarm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Stopwatch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_bottom),
            label: 'Timer',
          ),
        ],
      ),
    );
  }

  Widget _buildWorldClockTab() {
    return Center(
      child: Container(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Clock face with button-like hour indicators
              ...List.generate(12, (index) {
                final angle =
                    (index * pi / 6) - pi / 2; // -pi/2 to start at 12 o'clock
                final hourNumber = index == 0 ? 12 : index;
                final position = 'position_$hourNumber';
                final isPressed = _tappedPositions.isNotEmpty &&
                    _tappedPositions.last == position;

                return Positioned(
                  left: 150 + 110 * cos(angle) - 18, // Center the button
                  top: 150 + 110 * sin(angle) - 18, // Center the button
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tappedPositions.add(position);
                        _checkPattern();
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPressed
                            ? Colors.orangeAccent.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          '$hourNumber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Hour hand
              _buildClockHand(
                angle: (_now.hour % 12 + _now.minute / 60) * pi / 6 - pi / 2,
                length: 60,
                width: 4,
                color: Colors.white,
              ),

              // Minute hand
              _buildClockHand(
                angle: (_now.minute / 60) * 2 * pi - pi / 2,
                length: 90,
                width: 3,
                color: Colors.white70,
              ),

              // Second hand
              _buildClockHand(
                angle: (_now.second / 60) * 2 * pi - pi / 2,
                length: 100,
                width: 1,
                color: Colors.redAccent,
              ),

              // Center dot
              Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockHand({
    required double angle,
    required double length,
    required double width,
    required Color color,
  }) {
    return Positioned(
      left: 150,
      top: 150,
      child: Transform(
        alignment: Alignment.topLeft,
        transform: Matrix4.identity()
          ..translate(-width / 2, 0.0)
          ..rotateZ(angle),
        child: Container(
          width: width,
          height: length,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(width / 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 3,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmTab() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '${_now.hour}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        ..._alarms.map((alarm) => _buildAlarmTile(alarm)),
        const SizedBox(height: 16),
        Center(
          child: FloatingActionButton(
            backgroundColor: Colors.orange,
            onPressed: () {
              // Normally would show an alarm creation dialog
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmTile(AlarmClock alarm) {
    return ListTile(
      title: Text(
        '${alarm.time.hour}:${alarm.time.minute.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),
      subtitle: Text(
        _getAlarmDaysText(alarm),
        style: TextStyle(color: Colors.grey),
      ),
      trailing: Switch(
        value: alarm.isActive,
        activeColor: Colors.orange,
        onChanged: (value) {
          setState(() {
            alarm.isActive = value;
          });
        },
      ),
    );
  }

  String _getAlarmDaysText(AlarmClock alarm) {
    if (alarm.daysActive.isEmpty) return 'One time';
    if (alarm.daysActive.length == 7) return 'Every day';

    final List<String> dayAbbreviations = [
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return alarm.daysActive.map((day) => dayAbbreviations[day]).join(', ');
  }

  Widget _buildStopwatchTab() {
    return const Center(
      child: Text(
        'Stopwatch',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTimerTab() {
    return const Center(
      child: Text(
        'Timer',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

class AlarmClock {
  final TimeOfDay time;
  bool isActive;
  final Set<int> daysActive; // 1-7 for Monday-Sunday
  final String label;

  AlarmClock({
    required this.time,
    required this.isActive,
    required this.daysActive,
    required this.label,
  });
}
