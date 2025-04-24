import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trippo_user/screens/login_screen.dart';
import 'package:trippo_user/screens/main_screen.dart';
import 'package:trippo_user/screens/register_screen.dart';
import 'package:trippo_user/screens/splashScreen/splash_screen.dart';
import 'package:trippo_user/screens/themeProvider/theme_provider.dart';
import 'firebase_options.dart';
import 'infoHandler/app_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => AppInfo(),
        child: MaterialApp(
          title: 'Flutter Demo',
          themeMode: ThemeMode.system,
          theme: MyThemes.lightTheme,
          darkTheme: MyThemes.darkTheme,
          debugShowCheckedModeBanner: false,
          home: SplashScreen(),
        ),
    );
  }
}
