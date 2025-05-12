import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class CalendarDisguise extends StatefulWidget {
  final String correctPin;
  final VoidCallback onAuthSuccess;

  const CalendarDisguise({
    super.key,
    required this.correctPin,
    required this.onAuthSuccess,
  });

  @override
  State<CalendarDisguise> createState() => _CalendarDisguiseState();
}

class _CalendarDisguiseState extends State<CalendarDisguise> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Track the sequence of taps for authentication
  List<String> _authSequence = [];
  bool _showingYears = false;
  bool _showingMonths = false;

  @override
  Widget build(BuildContext context) {
    Logger().d('CalendarDisguise build _authSequence: $_authSequence');
    // Check the PIN sequence using the PIN code digits
    final List<String> pinDigits = widget.correctPin.split('');
    final requiredSequence = [
      'today', // First tap today button
      'year:${_getTargetYear(pinDigits)}', // Tap year (using first two PIN digits)
      'month:${_getTargetMonth(pinDigits)}', // Tap month (using third PIN digit)
      'day:${_getTargetDay(pinDigits)}', // Tap day (using fourth PIN digit)
    ];

    // Check if auth sequence is correct
    if (_authSequence.length >= requiredSequence.length) {
      bool isCorrect = true;
      for (int i = 0; i < requiredSequence.length; i++) {
        if (requiredSequence[i] != _authSequence[i]) {
          isCorrect = false;
          break;
        }
      }

      if (isCorrect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onAuthSuccess();
        });
      } else {
        // Reset sequence if wrong
        if (_authSequence.length > requiredSequence.length) {
          setState(() {
            _authSequence = [];
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime.now();
                _selectedDay = DateTime.now();
                _authSequence.add('today');
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () {
              setState(() {
                if (!_showingYears && !_showingMonths) {
                  _showingYears = true;
                  _showingMonths = false;
                } else if (_showingYears && !_showingMonths) {
                  _showingYears = false;
                  _showingMonths = true;
                } else {
                  _showingYears = false;
                  _showingMonths = false;
                }
              });
            },
          ),
        ],
      ),
      body: _showingYears
          ? _buildYearSelector()
          : _showingMonths
              ? _buildMonthSelector()
              : _buildCalendar(),
    );
  }

  String _getTargetYear(List<String> pinDigits) {
    // Use first two digits of PIN to determine year (e.g., pin 1234 -> year 2012)
    return "20${pinDigits[0]}${pinDigits[1]}";
  }

  String _getTargetMonth(List<String> pinDigits) {
    // Use third digit of PIN to determine month (limit to 1-12)
    final int monthDigit = int.parse(pinDigits[2]);
    // Make sure month is valid (1-12)
    return (monthDigit == 0
            ? 10
            : (monthDigit > 9 ? monthDigit % 9 : monthDigit))
        .toString();
  }

  String _getTargetDay(List<String> pinDigits) {
    // Use fourth digit of PIN to determine day (limit to valid day of month)
    final int dayDigit = int.parse(pinDigits[3]);
    // Make sure day is valid (1-28 for simplicity)
    return (dayDigit == 0 ? 10 : (dayDigit > 28 ? dayDigit % 28 : dayDigit))
        .toString();
  }

  Widget _buildCalendar() {
    // Get days in the current month
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekdayOfMonth = firstDayOfMonth.weekday;

    // Month name and year
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Column(
      children: [
        // Month and year header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                      1,
                    );
                    _authSequence.add('month:${_focusedMonth.month}');
                  });
                },
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showingMonths = true;
                    _showingYears = false;
                  });
                },
                child: Text(
                  '${monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                      1,
                    );
                    _authSequence.add('month:${_focusedMonth.month}');
                  });
                },
              ),
            ],
          ),
        ),

        // Weekday header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: const [
              Expanded(child: Center(child: Text('Mon'))),
              Expanded(child: Center(child: Text('Tue'))),
              Expanded(child: Center(child: Text('Wed'))),
              Expanded(child: Center(child: Text('Thu'))),
              Expanded(child: Center(child: Text('Fri'))),
              Expanded(child: Center(child: Text('Sat'))),
              Expanded(child: Center(child: Text('Sun'))),
            ],
          ),
        ),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: 42, // 6 rows * 7 columns
            itemBuilder: (context, index) {
              // Adjust for weekday offset (Monday=1, but we need 0-based index)
              final adjustedFirstWeekday = firstWeekdayOfMonth - 1;
              final day = index - adjustedFirstWeekday + 1;

              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isToday = _isToday(date);
              final isSelected = _isSameDay(_selectedDay, date);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = date;
                    _authSequence.add('day:$day');
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue
                        : isToday
                            ? Colors.blue.withOpacity(0.3)
                            : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? Colors.blue.shade900
                                : null,
                        fontWeight:
                            isSelected || isToday ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Events section
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: Text('Selected: ${_formatDate(_selectedDay)}'),
                leading: const Icon(Icons.calendar_today),
              ),
              const Divider(),
              const ListTile(
                title: Text('No Events'),
                subtitle: Text('Tap + to add an event'),
                leading: Icon(Icons.event_note),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    // Generate years from 1900 to 2099 to cover all possible 2-digit combinations
    final int baseYear =
        (currentYear ~/ 100) * 100; // Get the century (e.g., 2000 from 2023)
    final List<int> years = List.generate(100, (index) => baseYear + index);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        return InkWell(
          onTap: () {
            setState(() {
              _focusedMonth = DateTime(year, _focusedMonth.month, 1);
              _showingYears = false;
              _authSequence.add('year:$year');
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: year == _focusedMonth.year
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              year.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: year == _focusedMonth.year
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1; // 1-based month
        return InkWell(
          onTap: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, month, 1);
              _showingMonths = false;
              _authSequence.add('month:$month');
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: month == _focusedMonth.month
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              monthNames[index],
              style: TextStyle(
                fontSize: 16,
                fontWeight: month == _focusedMonth.month
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
