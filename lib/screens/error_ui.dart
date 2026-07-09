import 'package:flutter/material.dart';
import 'onboarding_ui.dart';


// if person choose gas, then show this error screen
// This would typically be handled by passing a parameter to the widget or using a navigation approach

class ErrorScreen extends StatelessWidget {
  //constructor
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
            const SizedBox(height: 20),
            const Text(
              'These updates are on the way yet!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please try again later.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  

}