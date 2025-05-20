import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';
import '../../../domain/utils/app_switcher.dart';
import 'package:data/domain/app_disguise_type.dart';
import '../../../domain/utils/disguise_preferences.dart';

class DisguisePinSettings extends ConsumerStatefulWidget {
  const DisguisePinSettings({super.key});

  @override
  ConsumerState<DisguisePinSettings> createState() =>
      _DisguisePinSettingsState();
}

class _DisguisePinSettingsState extends ConsumerState<DisguisePinSettings> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  AppDisguiseType _currentDisguiseType = AppDisguiseType.none;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    // Get local PIN from SharedPreferences
    final disguiseType = await AppSwitcher.getCurrentDisguiseType();

    setState(() {
      _currentDisguiseType = disguiseType;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disguise PIN Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your disguise authentication PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This PIN will be used to access your gallery from any disguise screen. '
                'Choose a PIN that is easy for you to remember but hard for others to guess.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'New PIN Code',
                  hintText: 'Enter a 6 digit PIN',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a PIN';
                  }
                  if (value.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  if (!RegExp(r'^\d+$').hasMatch(value)) {
                    return 'PIN must contain only digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPinController,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN Code',
                  hintText: 'Enter the same PIN again',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your PIN';
                  }
                  if (value != _pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _savePin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save PIN', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Disguise Options:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDisguiseSelector(),
              // const SizedBox(height: 24),
              // Center(
              //   child: ElevatedButton(
              //     onPressed: _saveDisguiseType,
              //     style: ElevatedButton.styleFrom(
              //       minimumSize: const Size(200, 50),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //     ),
              //     child: const Text(
              //       'Apply Disguise',
              //       style: TextStyle(fontSize: 16),
              //     ),
              //   ),
              // ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Tips for using disguise screens:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const ListTile(
                leading: Icon(Icons.calculate),
                title: Text('Calculator Disguise'),
                subtitle: Text(
                  'Enter your PIN and press the equals (=) key to access your hidden gallery.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Calendar Disguise'),
                subtitle: Text(
                  'Tap on dates that match your PIN sequence. For example, if your PIN is 123456, tap dates 1, 2, 3, 4, 5, and 6. Use the Today button as 0.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.note),
                title: Text('Notes Disguise'),
                subtitle: Text(
                  'Create a new note and start it in the content section with your PIN followed by = (example: 123456=). This will unlock your gallery while keeping your media secure.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.watch_later),
                title: Text('Clock Disguise'),
                subtitle: Text(
                  'Tap hour positions on the clock that match your 6-digit PIN. The hour 12 represents 0. For example, if your PIN is 123450, tap hours 1, 2, 3, 4, 5, and 12 in sequence to unlock your gallery.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePin() async {
    if (_formKey.currentState!.validate()) {
      final pin = _pinController.text;

      // Save hashed PIN to Firebase
      final appSettingsService = ref.read(appSettingsServiceProvider);
      await DisguisePreferences.setPinHashFirebase(pin, appSettingsService);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN saved successfully')),
        );
        // Clear the text fields
        _pinController.clear();
        _confirmPinController.clear();
      }
    }
  }

  Widget _buildDisguiseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Select app disguise type '),
              TextSpan(
                text: '(it will automatically restart app to apply)',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ':'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _buildDisguiseOption(
              AppDisguiseType.none,
              'No Disguise',
              Icons.phone_android,
            ),
            _buildDisguiseOption(
              AppDisguiseType.calculator,
              'Calculator',
              Icons.calculate,
            ),
            _buildDisguiseOption(
              AppDisguiseType.calendar,
              'Calendar',
              Icons.calendar_today,
            ),
            _buildDisguiseOption(AppDisguiseType.notes, 'Notes', Icons.note),
            _buildDisguiseOption(
              AppDisguiseType.clock,
              'Clock',
              Icons.access_time,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisguiseOption(
    AppDisguiseType type,
    String label,
    IconData icon,
  ) {
    final isSelected = _currentDisguiseType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _currentDisguiseType = type;
          _saveDisguiseType();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? context.colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colorScheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDisguiseType() async {
    try {
      if (mounted) {
        // Update the provider
        ref.read(disguiseTypeProvider.notifier).state = _currentDisguiseType;

        updateAppDisguiseType(
          _currentDisguiseType,
          ref.read(appSettingsServiceProvider),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'App disguise changed to ${_getDisguiseName(_currentDisguiseType)}',
            ),
          ),
        );
      }
      AppSwitcher.switchAppLauncher(_currentDisguiseType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change app disguise: $e')),
        );
      }
    }
  }

  String _getDisguiseName(AppDisguiseType type) {
    switch (type) {
      case AppDisguiseType.none:
        return 'None';
      case AppDisguiseType.calculator:
        return 'Calculator';
      case AppDisguiseType.calendar:
        return 'Calendar';
      case AppDisguiseType.notes:
        return 'Notes';
      case AppDisguiseType.weather:
        return 'Weather';
      case AppDisguiseType.clock:
        return 'Clock';
    }
  }
}
