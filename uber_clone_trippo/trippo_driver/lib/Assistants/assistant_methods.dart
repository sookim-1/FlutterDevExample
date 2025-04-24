
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trippo_driver/Assistants/request_assistant.dart';
import 'package:trippo_driver/global/global.dart';
import 'package:trippo_driver/global/map_key.dart';
import 'package:trippo_driver/models/direction_details_info.dart';
import 'package:trippo_driver/models/directions.dart';

import '../infoHandler/app_info.dart';
import '../models/user_model.dart';

class AssistantMethods {

  static void readCurrentOnlineUserInfo() async {
    currentUser = firebaseAuth.currentUser;

    DatabaseReference driverRef = FirebaseDatabase.instance
    .ref()
    .child('drivers')
    .child(currentUser!.uid);

    driverRef.once().then((snap) {
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

  static pauseLiveLocationUpdates() {
    streamSubscriptionPosition!.pause();
    Geofire.removeLocation(firebaseAuth.currentUser!.uid);
  }

  static double calculateFareAmountFromOriginToDestination(DirectionDetailsInfo directionDetailsInfo) {
    double timeTraveledFareAmountPerMinute = (directionDetailsInfo.duration_value! / 60) * 0.1;
    double distanceTraveledFareAmountPerKilometer = (directionDetailsInfo.duration_value! / 1000) * 0.1;

    // USD
    double totalFareAmount = timeTraveledFareAmountPerMinute + distanceTraveledFareAmountPerKilometer;
    double localCurrencyTotalFare = totalFareAmount * 107;

    if (driverVehicleType == 'Bike') {
      double resultFareAmount = ((localCurrencyTotalFare.truncate()) * 0.8);
      resultFareAmount;
    }
    else if (driverVehicleType == 'CNG') {
      double resultFareAmount = ((localCurrencyTotalFare.truncate()) * 1.5);
      resultFareAmount;
    }
    else if (driverVehicleType == 'Car') {
      double resultFareAmount = ((localCurrencyTotalFare.truncate()) * 2);
      resultFareAmount;
    }
    else {
      return localCurrencyTotalFare.truncate().toDouble();
    }

    return localCurrencyTotalFare.truncate().toDouble();
  }

}