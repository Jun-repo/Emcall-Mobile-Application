// ignore_for_file: use_build_context_synchronously

import 'package:emcall/auth/forms/login_form.dart';
import 'package:emcall/components/onboarding/onboarding_view.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';
import 'package:emcall/containers/residents/pages/resident_home_page.dart';
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
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdnaG9mbWVvdXlhdnJjZGZ3Y3N3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA3NTg1MzQsImV4cCI6MjA0NjMzNDUzNH0.IEmi_a1vIepHSv9D0b29HJ8NOKOsMx_OwDYXey2NHGo',
  );

  final prefs = await SharedPreferences.getInstance();
  final onboarding = prefs.getBool("onboarding") ?? false;
  final loggedIn = prefs.getBool("loggedIn") ?? false;
  Widget home;

  if (!onboarding) {
    home = const OnboardingView();
  } else if (loggedIn) {
    final userType = prefs.getString("userType");
    if (userType == "resident") {
      final firstName = prefs.getString("firstName") ?? "";
      final middleName = prefs.getString("middleName") ?? "";
      final lastName = prefs.getString("lastName") ?? "";
      final suffix = prefs.getString("suffix") ?? "";
      home = ResidentHomePage(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        suffix: suffix,
      );
    } else if (userType == "organization") {
      final orgName = prefs.getString("orgName") ?? "Organization";
      final orgAddress =
          prefs.getString("orgAddress") ?? "Address not provided";
      home = OrganizationHomePage(orgName: orgName, orgAddress: orgAddress);
    } else {
      home = const LoginForm();
    }
  } else {
    home = const LoginForm();
  }

  runApp(MainApp(home: home));
}

Future<void> setup() async {
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_ACCESS_TOKEN"]!);
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
