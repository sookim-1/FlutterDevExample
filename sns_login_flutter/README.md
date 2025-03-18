# sns_login_flutter

SNS로그인 Flutter 예제

## dotenv APIKey 숨김처리

> 참고링크
- 공식패키지 : [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)
- manifestPlaceholders : [플러터에서 androidManifest에 localProperties 값 대입하기](https://android-developer.tistory.com/53)
- dotenve 외 고려할점 : [Flutter에서 환경변수 설정하기](https://jay-flow.medium.com/flutter%EC%97%90%EC%84%9C-%ED%99%98%EA%B2%BD%EB%B3%80%EC%88%98-%EC%96%B4%EB%96%BB%EA%B2%8C-%EC%84%A4%EC%A0%95%ED%95%98%EB%8A%94-%EA%B2%83%EC%9D%B4-%EC%B5%9C%EC%84%A0%EC%9D%BC%EA%B9%8C-6e7b81efc76e)
- .env를 통해 API Key 안전하게 사용 (AndroidManifest.xml에서의 사용 포함 / 환경변수 설정) : [.env 설정방법 안드로이드 포함](https://monosandalos.tistory.com/75)


1. dotenv 의존성 설치하기

```yaml
dependencies:
  flutter_dotenv: ^5.2.1
```

2. 설정
- `.env` 파일 추가
   ```
  KAKAO_NATIVE_APP_KEY=123456789ab
  ```

- 추가한 파일 pubspec.yaml assets에 .env 파일 경로 추가
   ```yaml
   assets:
      - assets/config/.env
   ```

- `.gitignore`에 *.env 추가

3. 로드

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future main() async {
   await dotenv.load(fileName: "assets/config/.env");
   String api_key = dotenv.env['KAKAO_NATIVE_APP_KEY'];
   //...runapp
}
```
### iOS
- `API_KEY.xcconfig` 파일 추가
  ```
  KAKAO_NATIVE_APP_KEY=123456789ab
  ```

- `.gitignore`에 *.API_KEY.xcconfig 추가

- Debug.xcconfig, Release.xcconfig에 API_KEY.xcoonfig Include (주의할점은 Generated.xcconfig보다 먼저 include 해줘야합니다.)
   ```
   #include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
   #include "API_KEY.xcconfig"
   #include "Generated.xcconfig"
  ```

### 안드로이드
- local.properties를 활용하거나 기존 .env를 설정해도 되지만 Flutter에서는 한번에 처리하도록 .env 사용
- app/build.gradle 설정 : minSdk 21버전으로 설정, .env의 키값을 가져와서 manifestPlaceholders에 키값 추가 (= 으로 하면 ${applicationName}에서 에러발생)

```
android {
    def kakaoKey = {
        def properties = new Properties()
        file("${rootProject.projectDir}/../assets/config/.env").withInputStream { stream -> properties.load(stream) }
        def kakaoKey = properties.getProperty("KAKAO_NATIVE_APP_KEY")
        assert kakaoKey != null, "kakaoKey not set in .env"
        return kakaoKey
    }()

    ...
    
    defaultConfig {
        applicationId = "com.sookim.sns_login_flutter"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders += [
                KAKAO_NATIVE_APP_KEY: kakaoKey
        ]
    }
    
    ...
}
```

- app/src/main/AndroidManifest.xml
```
${KAKAO_NATIVE_APP_KEY} 로 사용
```




## 카카오 로그인 

> 참고링크
- 공식문서 : [Kakao Developers](https://developers.kakao.com/docs/latest/ko/kakaologin/flutter#set-custom-url-scheme)
- pub.dev : [developers.kakao.com](https://pub.dev/publishers/developers.kakao.com/packages)
- 카카오로그인 : [Flutter OAuth, Kakao Login 개발](https://malangdidoo.tistory.com/257)
- 카카오로그인 with Provider : [Flutter Kakao Login 구현](https://velog.io/@qazws78941/FlutterKakao-login-api%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EB%A1%9C%EA%B7%B8%EC%9D%B8)

1. 의존성 설치 - pubspec.yaml

```yaml
dependencies:
  kakao_flutter_sdk_user: ^1.9.5 # 카카오 로그인 API 패키지
```

2. 카카오 내 애플리케이션 생성

[플랫폼확인](https://developers.kakao.com/docs/latest/ko/getting-started/app#platform)

- iOS 번들 ID 등록 : Xcode Runner 프로젝트파일에서 번들 ID 확인
- 안드로이드 패키지명 등록 : app/build.gradle의 applicationId 값 확인

3. dart Code 추가
```dart
// 초기화 
void main() async {
  KakaoSdk.init(
    nativeAppKey: '${kakaoNativeAppKey}',
  );

  runApp(const MyApp());
}

// 로그인
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
                  '\n이메일: ${user.kakaoAccount?.email}';
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
                '\n이메일: ${user.kakaoAccount?.email}';
      });
    } catch (error) {
      setState(() {
        _snsData = '카카오계정 로그인 실패'
                '\n ${error}';
      });
    }
  }
}

```

### iOS URL Scheme 설정
- Info.plist - Queried URL Schemes 배열 - Item에 `kakaokompassauth` 값 추가
- URL Types - URL Schemes `kakao${NativeAppKey}` 추가

### 안드로이드 URL Scheme 설정
- app/src/main/AndroidManifest.xml 설정
```
<!-- 카카오 로그인 커스텀 URL 스킴 설정 -->
<activity
android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
android:exported="true">
<intent-filter android:label="flutter_web_auth">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <!-- "kakao${YOUR_NATIVE_APP_KEY}://oauth" 형식의 앱 실행 스킴 설정 -->
    <!-- 카카오 로그인 Redirect URI -->
    <data android:scheme="kakao${KAKAO_NATIVE_APP_KEY}" android:host="oauth"/>
</intent-filter>
</activity>
```