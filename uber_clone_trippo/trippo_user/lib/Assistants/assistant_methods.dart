
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trippo_user/Assistants/request_assistant.dart';
import 'package:trippo_user/global/global.dart';
import 'package:trippo_user/global/map_key.dart';
import 'package:trippo_user/models/direction_details_info.dart';
import 'package:trippo_user/models/directions.dart';
import 'package:trippo_user/models/trips_history_model.dart';

import '../infoHandler/app_info.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;

class AssistantMethods {

  static void readCurrentOnlineUserInfo() async {
    currentUser = firebaseAuth.currentUser;

    DatabaseReference userRef = FirebaseDatabase.instance
    .ref()
    .child('users')
    .child(currentUser!.uid);

    userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        userModelCurrentInfo = UserModel.fromSnapShot(snap.snapshot);
      }
    });
  }

  static Future<String> searchAddressForGeographicCoordinates(Position position, context) async {
    String apiUrl = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey';
    String humanReadableAddress = '';

    var requestResponse = await RequestAssistant.receiveRequest(apiUrl);

    if (requestResponse != 'Network Error') {
      humanReadableAddress = requestResponse['results'][0]['formatted_address'];

      Directions userPickUpAddress = Directions();
      userPickUpAddress.locationLatitude = position.latitude;
      userPickUpAddress.locationLongitude = position.longitude;
      userPickUpAddress.locationName = humanReadableAddress;

      Provider.of<AppInfo>(context, listen: false).updatePickUpLocationAddress(userPickUpAddress);
    }

    return humanReadableAddress;
  }

  static Future<DirectionDetailsInfo> obtainOriginToDestinationDirectionDetails(LatLng originPosition, LatLng destinationPosition) async {
    print('경로조회 요청좌표 ${originPosition} : ${destinationPosition}' );

    // FIXME: GoogleMaps 는 한국을 지원하지 않아서 주의
    // String sampleURL = 'https://maps.googleapis.com/maps/api/directions/json?origin=13.76515,100.53904&destination=13.7329,100.52898&key=${mapKey}';

    String urlOriginToDestinationDirectionDetails = 'https://maps.googleapis.com/maps/api/directions/json?origin=${originPosition.latitude},${originPosition.longitude}&destination=${destinationPosition.latitude},${destinationPosition.longitude}&key=${mapKey}';

    var responseDirectionApi = await RequestAssistant.receiveRequest(urlOriginToDestinationDirectionDetails);

    // if (responseDirectionApi == 'Network Error') {
    //   return null;
    // }

    DirectionDetailsInfo directionDetailsInfo = DirectionDetailsInfo();
    directionDetailsInfo.e_points = responseDirectionApi['routes'][0]['overview_polyline']['points'];

    directionDetailsInfo.distance_text = responseDirectionApi['routes'][0]['legs'][0]['distance']['text'];
    directionDetailsInfo.distance_value = responseDirectionApi['routes'][0]['legs'][0]['distance']['value'];

    directionDetailsInfo.duration_text = responseDirectionApi['routes'][0]['legs'][0]['duration']['text'];
    directionDetailsInfo.duration_value = responseDirectionApi['routes'][0]['legs'][0]['duration']['value'];

    print('경로조회 응답값: ${directionDetailsInfo}');


    return directionDetailsInfo;
  }

  static double calculateFareAmountFromOriginToDestination(DirectionDetailsInfo directionDetailsInfo) {
    double timeTraveledFareAmountPerMinute = (directionDetailsInfo.duration_value! / 60) * 0.1;
    double distanceTraveledFareAmountPerKilometer = (directionDetailsInfo.duration_value! / 1000) * 0.1;

    // USD
    double totalFareAmount = timeTraveledFareAmountPerMinute + distanceTraveledFareAmountPerKilometer;

    return double.parse(totalFareAmount.toStringAsFixed(1));
  }

  static Future<String> getAccessToken() async {
    final serviceAccountJson =
      {
        "type": "",
        "project_id": "",
        "private_key_id": "",
        "private_key": "",
        "client_email": "",
        "client_id": "",
        "auth_uri": "",
        "token_uri": "",
        "auth_provider_x509_cert_url": "",
        "client_x509_cert_url": "",
        "universe_domain": ""
      };

    List<String> scopes =
        [
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/firebase.database',
          'https://www.googleapis.com/auth/firebase.messaging',
        ];

    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );

    // get the access token
    auth.AccessCredentials credentials = await auth.obtainAccessCredentialsViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
      client
    );

    client.close();

    return credentials.accessToken.data;
  }

  // Noitification 변경해야함 - https://firebase.google.com/docs/cloud-messaging/migrate-v1?hl=ko#go
  static sendNotificationToDriverNow(String deviceRegistrationToken, String userRideRequestId, context) async {
    final String serverAccessTokenKey = await getAccessToken();
    String endpointFirebaseCloudMessaging = 'https://fcm.googleapis.com/v1/projects/{YOUR_RPOJECT_ID}/messages:send';
    String destinationAddress = userDropOffAddress;

    Map dataMap = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'id': '1',
      'status': 'done',
      'rideRequestId': userRideRequestId
    };

    Map bodyNotification = {
      'body': 'Destination Address: \n$destinationAddress.',
      'title': 'New Trip Request'
    };

    Map<String, String> headerNotification = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${serverAccessTokenKey}',
    };

    final Map<String, dynamic> message =
    {
      'message': {
        'token': deviceRegistrationToken,
        'notification': bodyNotification,
        'data': dataMap,
      }
    };

    final http.Response response = await http.post(
      Uri.parse(endpointFirebaseCloudMessaging),
      headers: headerNotification,
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('푸시 발송 성공');
    }
    else {
      print('푸시 발송 실패 ${response.statusCode}');
    }
  }

  // Cloud Messaging API(기존)
  static legacySendNotificationToDriverNow(String deviceRegistrationToken, String userRideRequestId, context) async {
    String destinationAddress = userDropOffAddress;

    // cloudMessagingServerToken -> 기존 Cloud Messaging 토큰
    String cloudMessagingServerToken = '';

    Map<String, String> headerNotification = {
      'Content-Type': 'application/json',
      'Authorization': cloudMessagingServerToken,
    };

    Map bodyNotification = {
      'body': 'Destination Address: \n$destinationAddress.',
      'title': 'New Trip Request'
    };

    Map dataMap = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'id': '1',
      'status': 'done',
      'rideRequestId': userRideRequestId
    };

    Map officialNotificationFormat = {
      'notification': bodyNotification,
      'data': dataMap,
      'priority': 'high',
      'to': deviceRegistrationToken,
    };

    var responseNotification = http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: headerNotification,
      body: jsonEncode(officialNotificationFormat),
    );
  }

  // retrieve the trips Keys for online user
  // trip key = ride request key
  static void readTripKeysForOnlineUser(context) {
    FirebaseDatabase.instance.ref().child('All Ride Requests').orderByChild('userName').equalTo(userModelCurrentInfo!.name).once().then((snap) {
      if (snap.snapshot.value != null) {
        Map keysTripsId = snap.snapshot.value as Map;

        // count toal number of trips and share it with Provider
        int overAllTripsCounter = keysTripsId.length;
        Provider.of<AppInfo>(context, listen: false).updateOverAllTripsCounter(overAllTripsCounter);

        // share trips keys with provider
        List<String> tripsKeysList = [];
        keysTripsId.forEach((key, value) {
          tripsKeysList.add(key);
        });

        Provider.of<AppInfo>(context, listen: false).updateOverAllTripsKeys(tripsKeysList);

        // get trips keys data - read trips complete information
        readTripsHistoryInformation(context);
      }
    });
  }

  static void readTripsHistoryInformation(context) {
    var tripsAllKeys = Provider.of<AppInfo>(context, listen: false).historyTripsKeysList;

    for (String eachKey in tripsAllKeys) {
      FirebaseDatabase.instance.ref()
          .child('All Ride Requests')
          .child(eachKey)
          .once()
          .then((snap) {
            var eachTripsHistory = TripsHistoryModel.fromSnapshot(snap.snapshot);

            if ((snap.snapshot.value as Map)['status'] == 'ended') {
              // update or add each history to OverAllTrips History data list
              Provider.of<AppInfo>(context, listen: false).updateOverAllTripsHistoryInformation(eachTripsHistory);
            }
      });
    }
  }


}