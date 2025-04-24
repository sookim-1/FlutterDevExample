// import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trippo_driver/global/global.dart';
import 'package:trippo_driver/models/user_ride_request_information.dart';

import 'notification_dialog_box.dart';

class PushNotificationsSystem {

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future initalizeCloudMessaging(BuildContext context) async {
    requestNotificationPermission();

    // 1. Terminated
    // When the app is closed and opend directly from the push notification
    FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? remoteMessage) {
      if (remoteMessage != null) {
        readUserRideRequestInformation(
            remoteMessage.data['rideRequestId'], context);
      }
    });

    // 2. Foreground
    // When the app is open and receives a push notification
    FirebaseMessaging.onMessage.listen((RemoteMessage? remoteMessage) {
      readUserRideRequestInformation(
          remoteMessage!.data['rideRequestId'], context);
    });

    // 3. Background
    // When the app is in then background and opened directly from the push notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? remoteMessage) {
      readUserRideRequestInformation(
          remoteMessage!.data['rideRequestId'], context);
    });
  }

  // 권한 요청
  requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('user granted permission');
    }
    else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('user provisional granted permission');
    }
    else {
      Fluttertoast.showToast(msg: 'Notification permission denied');

      Future.delayed(Duration(seconds: 2), () {
        AppSettings.openAppSettings(type: AppSettingsType.notification);
      });
    }

  }

  readUserRideRequestInformation(String userRideRequestId,
      BuildContext context) {
    FirebaseDatabase.instance
        .ref()
        .child('All Ride Requests')
        .child(userRideRequestId)
        .child('driverId')
        .onValue
        .listen((event) {
      if (event.snapshot.value == 'waiting' ||
          event.snapshot.value == firebaseAuth.currentUser!.uid) {
        FirebaseDatabase.instance.ref().child('All Ride Requests').child(
            userRideRequestId).once().then((snapData) {
          if (snapData.snapshot.value != null) {
            /* audioPlayer 오류
            audioPlayer.open(Audio('music/music_notification.mp3'));
            audioPlayer.play();
            */

            double originLat = double.parse(
                (snapData.snapshot.value! as Map)['origin']['latitude']);
            double originLng = double.parse(
                (snapData.snapshot.value! as Map)['origin']['longitude']);
            String originAddress = (snapData.snapshot
                .value! as Map)['originAddress'];

            double destinationLat = double.parse(
                (snapData.snapshot.value! as Map)['destination']['latitude']);
            double destinationLng = double.parse(
                (snapData.snapshot.value! as Map)['destination']['longitude']);
            String destinationAddress = (snapData.snapshot
                .value! as Map)['destinationAddress'];

            String userName = (snapData.snapshot.value! as Map)['userName'];
            String userPhone = (snapData.snapshot.value! as Map)['userPhone'];

            String? rideRequestId = snapData.snapshot.key;

            UserRideRequestInformation userRideRequestDetails = UserRideRequestInformation();
            userRideRequestDetails.originLatLng = LatLng(originLat, originLng);
            userRideRequestDetails.originAddress = originAddress;
            userRideRequestDetails.destinationLatLng =
                LatLng(destinationLat, destinationLng);
            userRideRequestDetails.destinationAddress = destinationAddress;
            userRideRequestDetails.userName = userName;
            userRideRequestDetails.userPhone = userPhone;

            userRideRequestDetails.rideRequestId = rideRequestId;

            showDialog(
                context: context,
                builder: (BuildContext context) =>
                    NotificationDialogBox(
                      userRideRequestDetails: userRideRequestDetails,
                    )
            );
          }
          else {
            Fluttertoast.showToast(msg: 'This Ride Request Id do not exists');
          }
        });
      }
      else {
        Fluttertoast.showToast(msg: 'This Ride Request has been cancelled');
        Navigator.pop(context);
      }
    });
  }

  Future generateAndGetToken() async {
    String? registrationToken = await messaging.getToken();
    print('FCM registration Token: ${registrationToken}');

    FirebaseDatabase.instance.ref()
        .child('drivers')
        .child(firebaseAuth.currentUser!.uid)
        .child('token')
        .set(registrationToken);

    messaging.subscribeToTopic('allDrivers');
    messaging.subscribeToTopic('allUsers');
  }

}

