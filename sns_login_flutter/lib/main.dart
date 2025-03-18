import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: "assets/config/.env");
  WidgetsFlutterBinding.ensureInitialized();
  String? kakaoNativeAppKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];

  KakaoSdk.init(
    nativeAppKey: kakaoNativeAppKey,
  );

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
            ElevatedButton(
                onPressed: _touchedFacebook, child: Text('페이스북 로그인')),
            ElevatedButton(onPressed: _touchedGoogle, child: Text('구글 로그인')),
            ElevatedButton(onPressed: _touchedApple, child: Text('애플 로그인')),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                '$_snsData',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _touchedKakao() async {
    // 카카오톡 실행이 가능하면 카카오톡으로 로그인, 아니면 카카오계정으로 로그인
    if (await isKakaoTalkInstalled()) {
      try {
        await UserApi.instance.loginWithKakaoTalk();
        User user = await UserApi.instance.me();

        setState(() {
          _snsData = '카카오톡 로그인 성공'
              '\n사용자 정보 요청 성공'
              '\n회원번호: ${user.id}'
              '\n닉네임: ${user.kakaoAccount?.profile?.nickname}'
              '\n프로필 URL: ${user.kakaoAccount?.profile?.profileImageUrl}';
        });
      } catch (error) {
        setState(() {
          _snsData = '카카오톡 로그인 실패'
              '\n ${error}';
        });

        // 사용자가 카카오톡 설치 후 디바이스 권한 요청 화면에서 로그인을 취소한 경우,
        // 의도적인 로그인 취소로 보고 카카오계정으로 로그인 시도 없이 로그인 취소로 처리 (예: 뒤로 가기)
        if (error is PlatformException && error.code == 'CANCELED') {
          return;
        }

        // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인
        try {
          await UserApi.instance.loginWithKakaoAccount();
          User user = await UserApi.instance.me();

          setState(() {
            _snsData = '카카오톡 연결된 계정이 없는 경우 로그인 성공'
                '\n사용자 정보 요청 성공'
                '\n회원번호: ${user.id}'
                '\n닉네임: ${user.kakaoAccount?.profile?.nickname}'
                '\n프로필 URL: ${user.kakaoAccount?.profile?.profileImageUrl}';
          });
        } catch (error) {
          setState(() {
            _snsData = '카카오톡 연결된 계정이 없는 경우 로그인 실패'
                '\n ${error}';
          });
        }
      }
    } else {
      try {
        await UserApi.instance.loginWithKakaoAccount();
        User user = await UserApi.instance.me();

        setState(() {
          _snsData = '카카오계정 로그인 성공'
              '\n사용자 정보 요청 성공'
              '\n회원번호: ${user.id}'
              '\n닉네임: ${user.kakaoAccount?.profile?.nickname}'
              '\n프로필 URL: ${user.kakaoAccount?.profile?.profileImageUrl}';
        });
      } catch (error) {
        setState(() {
          _snsData = '카카오계정 로그인 실패'
              '\n ${error}';
        });
      }
    }
  }

  void _touchedFacebook() {
    setState(() {
      _snsData = '페이스북 로그인';
    });
  }

  void _touchedGoogle() async {
    print('구글로그인 클릭');

    final GoogleSignIn _googleSignIn = GoogleSignIn(
      scopes: [
        'email'
      ]
    );

    var user = await _googleSignIn.signIn();

    setState(() {
      _snsData = '구글 로그인 성공'
          '\n사용자 정보 요청 성공'
          '\n회원번호: ${user?.id}'
          '\n닉네임: ${user?.displayName}'
          '\n이메일: ${user?.email}'
          '\n프로필 URL: ${user?.photoUrl}';
    });
  }

  void _touchedApple() {
    setState(() {
      _snsData = '애플 로그인';
    });
  }
}
