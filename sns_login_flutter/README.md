# sns_login_flutter

SNS로그인 Flutter 예제

# dotenv APIKey 숨김처리
공식패키지 : [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)

1. 의존성 설치
   pubspec.yaml

```yaml
dependencies:
  flutter_dotenv: ^5.2.1
```
2. 설정
- `.env` 파일 추가
   ```
  KAKAO_NATIVE_APP_KEY=123456789ab
  ```

- 추가한 파일 pubspec.yaml assets에 .env 경로 추가
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
## iOS
- `API_KEY.xcconfig` 파일 추가
   ```
  KAKAO_NATIVE_APP_KEY=123456789ab
  ```
- `.gitignore`에 *.API_KEY.xcconfig 추가
- Debug.xcconfig, Release.xcconfig에 API_KEY.xcoonfig Include 
  주의할점은 Generated.xcconfig보다 먼저 include 해줘야합니다.
   ```
  #include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
   #include "API_KEY.xcconfig"
   #include "Generated.xcconfig"
  ```




# 카카오 로그인 

공식문서 : [Kakao Developers](https://developers.kakao.com/docs/latest/ko/kakaologin/flutter#set-custom-url-scheme)
pub.dev : [developers.kakao.com](https://pub.dev/publishers/developers.kakao.com/packages)

1. 의존성 설치
pubspec.yaml

```yaml
dependencies:
  kakao_flutter_sdk_user: ^1.9.5 # 카카오 로그인 API 패키지
```

2. 카카오 내 애플리케이션 생성

- iOS 번들 ID 등록
- 안드로이드 패키지명 등록


## iOS
Info.plist - Queried URL Schemes 배열 - Item에 `kakaokompassauth` 값 추가
URL Types - URL Scemes `kakao${NativeAppKey}` 추가

