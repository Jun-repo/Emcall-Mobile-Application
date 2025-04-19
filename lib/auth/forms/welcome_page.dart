import 'package:emcall/auth/forms/select_user_type_page.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 251, 112, 84),
      // remove appBar if you don’t want one
      body: SizedBox.expand(
        child: Image.asset(
          'assets/icons/started_illustration.png',
          fit: BoxFit.cover,
        ),
      ),
      // if you still want the button overlaid on top of the image:
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const SelectUserTypePage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  final tween =
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.ease));
                  return SlideTransition(
                      position: animation.drive(tween), child: child);
                },
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            backgroundColor: Colors.white.withOpacity(0.8),
            foregroundColor: Colors.redAccent,
          ),
          child: const Text('Get Started',
              style: TextStyle(
                fontSize: 20,
              )),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
