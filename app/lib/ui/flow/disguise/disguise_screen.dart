import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/utils/app_switcher.dart';
import '../../../domain/utils/disguise_preferences.dart';
import '../../navigation/app_route.dart';
import 'layouts/calculator_disguise.dart';
import 'layouts/calendar_disguise.dart';
import 'layouts/notes_disguise.dart';
import 'layouts/clock_disguise.dart';

class DisguiseScreen extends ConsumerWidget {
  const DisguiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disguiseType = ref.watch(disguiseTypeProvider);
    final pinCode = ref.watch(disguisePinProvider);

    // Show loading indicator while PIN is loading
    if (pinCode is AsyncLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle error loading PIN
    if (pinCode is AsyncError) {
      return Scaffold(
        body: Center(
          child: Text('Error loading app: ${pinCode.error}'),
        ),
      );
    }

    final actualPin =
        pinCode.asData?.value ?? DisguisePreferences.defaultPinCode;

    // Successful PIN validation callback
    void onAuthSuccess() {
      HomeRoute().go(context);
    }

    // Show the appropriate disguise based on selected type
    switch (disguiseType) {
      case AppDisguiseType.calculator:
        return CalculatorDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
        );
      case AppDisguiseType.calendar:
        return CalendarDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
        );
      case AppDisguiseType.notes:
        return NotesDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
        );
      case AppDisguiseType.clock:
        return ClockDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
        );
      case AppDisguiseType.none:
      default:
        return _buildPinScreen(context, actualPin, onAuthSuccess);
    }
  }

  // Simple PIN entry screen when no disguise is selected
  Widget _buildPinScreen(
    BuildContext context,
    String correctPin,
    VoidCallback onAuthSuccess,
  ) {
    final TextEditingController pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Gallery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter PIN to access gallery',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'PIN',
                ),
                validator: (value) {
                  if (value != correctPin) {
                    return 'Incorrect PIN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    onAuthSuccess();
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Unlock', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
