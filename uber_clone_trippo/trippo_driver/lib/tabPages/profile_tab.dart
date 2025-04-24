import 'package:flutter/material.dart';

import '../global/global.dart';
import '../screens/splashScreen/splash_screen.dart';

class ProfileTabPage extends StatefulWidget {
  const ProfileTabPage({super.key});

  @override
  State<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends State<ProfileTabPage> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        firebaseAuth.signOut();
        Navigator.push(context, MaterialPageRoute(builder: (c) => SplashScreen()));
      },
      child: Center(
        child: Text(
          '로그아웃',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}
