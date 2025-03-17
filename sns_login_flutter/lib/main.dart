import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SNS Login Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'SNS Login Demo Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _snsData = '데이터 결과';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20.0,
          children: <Widget>[
            ElevatedButton(onPressed: _touchedKakao, child: Text('카카오 로그인')),
            ElevatedButton(onPressed: _touchedFacebook, child: Text('페이스북 로그인')),
            ElevatedButton(onPressed: _touchedGoogle, child: Text('구글 로그인')),
            ElevatedButton(onPressed: _touchedApple, child: Text('애플 로그인')),

            Text(
              '$_snsData',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  void _touchedKakao() {
    setState(() {
      _snsData = '카카오 로그인';
    });
  }

  void _touchedFacebook() {
    setState(() {
      _snsData = '페이스북 로그인';
    });
  }

  void _touchedGoogle() {
    setState(() {
      _snsData = '구글 로그인';
    });
  }

  void _touchedApple() {
    setState(() {
      _snsData = '애플 로그인';
    });
  }

}
