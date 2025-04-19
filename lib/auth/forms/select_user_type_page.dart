import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:flutter/material.dart';
import 'login_form.dart';
import 'enums.dart';

class SelectUserTypePage extends StatelessWidget {
  const SelectUserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 0.33,
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomePage()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Skip',
                style: TextStyle(color: Colors.black54, fontFamily: 'Gilroy')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.start,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Select User Type\n',
                        style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'Gilroy',
                        ),
                      ),
                      TextSpan(
                        text: 'What\'s your role?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: UserTypeCard(
                      userType: UserType.resident, label: 'People'),
                ),
                Center(
                  child: UserTypeCard(
                      userType: UserType.worker, label: 'Employee'),
                ),
                Center(
                  child: UserTypeCard(
                      userType: UserType.organization, label: 'Agency'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserTypeCard extends StatelessWidget {
  final UserType userType;
  final String label;

  const UserTypeCard({super.key, required this.userType, required this.label});

  IconData _getIconForUserType(UserType userType) {
    switch (userType) {
      case UserType.resident:
        return Icons.home_rounded;
      case UserType.worker:
        return Icons.work_rounded;
      case UserType.organization:
        return Icons.business_rounded;
    }
  }

  String _getBackgroundImage(UserType userType) {
    switch (userType) {
      case UserType.resident:
        return 'assets/images/community.png';
      case UserType.worker:
        return 'assets/images/worker.png';
      case UserType.organization:
        return 'assets/images/organization.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LoginForm(userType: userType),
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
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white,
            width: 4,
          ),
        ),
        elevation: 6,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: AssetImage(_getBackgroundImage(userType)),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          shadows: [
                            Shadow(
                              offset: Offset(1.0, 1.0),
                              blurRadius: 2.0,
                              color: Colors.white,
                            ),
                          ]),
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color.fromARGB(35, 255, 255, 255),
                      child: Icon(
                        _getIconForUserType(userType),
                        size: 20,
                        color: Colors.black,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
