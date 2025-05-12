import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';
import '../../../domain/utils/app_switcher.dart';
import '../../../domain/utils/disguise_preferences.dart';

class DisguisePinSettings extends ConsumerStatefulWidget {
  const DisguisePinSettings({super.key});

  @override
  _DisguisePinSettingsState createState() => _DisguisePinSettingsState();
}

class _DisguisePinSettingsState extends ConsumerState<DisguisePinSettings> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _currentPin;
  AppDisguiseType _currentDisguiseType = AppDisguiseType.none;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final pin = await DisguisePreferences.getPinCode();
    final disguiseType = await AppSwitcher.getCurrentDisguiseType();
    setState(() {
      _currentPin = pin;
      _currentDisguiseType = disguiseType;
    });
  }

  // Replaced with _loadCurrentSettings

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
              if (_currentPin != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Current PIN: ${_currentPin!.replaceAll(RegExp(r'.'), '*')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'New PIN Code',
                  hintText: 'Enter a 4-6 digit PIN',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a PIN';
                  }
                  if (value.length < 4 || value.length > 6) {
                    return 'PIN must be 4-6 digits';
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
                subtitle: Text('Enter your PIN and press = key'),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Calendar Disguise'),
                subtitle: Text(
                  'Follow the sequence: Today button → Year → Month → Day (matching PIN digits)',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.note),
                title: Text('Notes Disguise'),
                subtitle:
                    Text('Type your PIN followed by = character in any note'),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.watch_later),
                title: Text('Clock Disguise'),
                subtitle:
                    Text('Tap hour positions on the clock that match your PIN'),
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
      final success = await DisguisePreferences.setPinCode(_pinController.text);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN saved successfully')),
        );

        // Update the displayed PIN
        setState(() {
          _currentPin = _pinController.text;
        });

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
        const Text('Select app disguise type:'),
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
        });
        _saveDisguiseType();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withOpacity(0.1)
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
      await AppSwitcher.switchAppLauncher(_currentDisguiseType);
      if (mounted) {
        // Update the provider
        ref.read(disguiseTypeProvider.notifier).state = _currentDisguiseType;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'App disguise changed to ${_getDisguiseName(_currentDisguiseType)}',
            ),
          ),
        );
      }
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
