// ignore_for_file: use_build_context_synchronously

import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/components/onboarding/onboarding_view.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';
import 'package:emcall/containers/residents/pages/home_navigation_page.dart';
import 'package:emcall/containers/workers/pages/worker_home_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  await Supabase.initialize(
    url: 'https://gghofmeouyavrcdfwcsw.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  final prefs = await SharedPreferences.getInstance();
  final onboarding = prefs.getBool('onboarding') ?? false;
  final loggedIn = prefs.getBool('loggedIn') ?? false;
  Widget home;

  if (!onboarding) {
    home = const OnboardingView();
  } else if (loggedIn) {
    final userType = prefs.getString('userType');
    if (userType == 'resident') {
      home = const HomeNavigationPage(initialIndex: 1);
    } else if (userType == 'worker') {
      home = const WorkerHomePage();
    } else if (userType == 'organization') {
      final orgName = prefs.getString('orgName') ?? 'Organization';
      final orgAddress =
          prefs.getString('orgAddress') ?? 'Address not provided';

      home = OrganizationHomePage(orgName: orgName, orgAddress: orgAddress);
    } else {
      home = const WelcomePage();
    }
  } else {
    home = const WelcomePage();
  }

  runApp(MainApp(home: home));
}

Future<void> setup() async {
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
}

class MainApp extends StatelessWidget {
  final Widget home;
  const MainApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emcall App',
      home: home,
    );
  }
}
