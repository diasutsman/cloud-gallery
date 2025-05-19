import 'package:data/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data/domain/app_disguise_type.dart';
import 'package:data/services/app_settings_service.dart' as app_settings;
import '../../../domain/utils/disguise_preferences.dart';
import '../../navigation/app_route.dart';
import '../accounts/accounts_screen_view_model.dart';
import 'layouts/calculator_disguise.dart';
import 'layouts/calendar_disguise.dart';
import 'layouts/notes_disguise.dart';
import 'layouts/clock_disguise.dart';

class DisguiseScreen extends ConsumerWidget {
  const DisguiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disguiseType = ref.watch(
      accountsStateNotifierProvider.select((value) => value.appDisguiseType),
    );
    final pinCode = ref.watch(disguisePinProvider);

    ref.read(loggerProvider).d(
          'DisguiseScreen build disguiseType: $disguiseType, pinCode: $pinCode',
        );

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

    // We'll use this service in the PIN screen for verification

    // Successful PIN validation callback
    void onAuthSuccess() {
      HomeRoute().go(context);
    }

    // Show the appropriate disguise based on selected type
    // Firebase PIN verification function
    final appSettingsService =
        ref.read(app_settings.appSettingsServiceProvider);
    Future<bool> verifyPinWithFirebase(String pin) async {
      return await DisguisePreferences.verifyPinWithFirebase(
        pin,
        appSettingsService,
      );
    }

    switch (disguiseType) {
      case AppDisguiseType.calculator:
        return CalculatorDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
          verifyPin: verifyPinWithFirebase,
        );
      case AppDisguiseType.calendar:
        return CalendarDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
          verifyPin: verifyPinWithFirebase,
        );
      case AppDisguiseType.notes:
        return NotesDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
          verifyPin: verifyPinWithFirebase,
        );
      case AppDisguiseType.clock:
        return ClockDisguise(
          correctPin: actualPin,
          onAuthSuccess: onAuthSuccess,
          verifyPin: verifyPinWithFirebase,
        );
      case AppDisguiseType.none:
      default:
        return _buildPinScreen(context, actualPin, onAuthSuccess, ref);
    }
  }

  // Simple PIN entry screen when no disguise is selected
  Widget _buildPinScreen(
    BuildContext context,
    String correctPin,
    VoidCallback onAuthSuccess,
    WidgetRef ref,
  ) {
    final TextEditingController pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock & Key'),
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
                // No validation here, will validate with Firebase when button is pressed
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your PIN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    // Verify PIN against Firebase hash
                    final appSettingsService =
                        ref.read(app_settings.appSettingsServiceProvider);
                    final isValid =
                        await DisguisePreferences.verifyPinWithFirebase(
                      pinController.text,
                      appSettingsService,
                    );

                    if (isValid) {
                      onAuthSuccess();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Incorrect PIN')),
                      );
                    }
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
