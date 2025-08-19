import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:product_hunt/Auth/auth.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:product_hunt/services/adaptive.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Product Hunt',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // 🔁 Logged-in user: show adaptive Product Hunt style shell
            return const PHNavShell();
          }
          // 🚪 Not logged-in: show auth
          return const AuthScreen();
        },
      ),
    );
  }
}
