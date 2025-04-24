import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trippo_user/Assistants/assistant_methods.dart';
import 'package:trippo_user/Assistants/geofire_assistant.dart';
import 'package:trippo_user/Assistants/notification_service.dart';
import 'package:trippo_user/global/global.dart';
import 'package:trippo_user/global/map_key.dart';
import 'package:trippo_user/infoHandler/app_info.dart';
import 'package:trippo_user/models/active_nearby_available_drivers.dart';
import 'package:trippo_user/screens/precise_pickup_location.dart';
import 'package:trippo_user/screens/search_places_screen.dart';
import 'package:trippo_user/screens/splashScreen/splash_screen.dart';
import 'package:trippo_user/widgets/progress_dialog.dart';

import '../models/directions.dart';
import '../widgets/pay_fare_amount_dialog.dart';
import 'drawer_screen.dart';
import 'rate_driver_screen.dart';

Future<void> _makePhoneCall(String url) async {

  /*
  if (await canLaunch(url)) {
    await launch(url);
  }
  else {
   throw 'Could not launch $url'
  }
  */
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  LatLng? pickLocation;
  loc.Location location = loc.Location();
  String? _address;

  final Completer<GoogleMapController> _controllerGoogleMap =
  Completer();
  GoogleMapController? newGoogleMapController;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  double searchLocationContainerHeight = 220;
  double waitingResponsefromDriverContainerHeight = 0;
  double assignedDriverInfoContainerHeight = 0;
  double suggestedRidesContainerHeight = 0;
  double searchingForDriverContainerHeight = 0;

  // geolocator로 좌표 얻기
  Position? userCurrentPosition;
  var geoLocation = Geolocator();

  LocationPermission? _locationPermission;
  double bottomPaddingOfMap = 0;

  // location -> LatLng
  List<LatLng> pLineCoordinatedList = [];

  // googlemap -> Polyline, Marker, Circle
  Set<Polyline> polylineSet = {};

  Set<Marker>  markersSet = {};
  Set<Circle> circlesSet = {};

  String userName = '';
  String userEmail = '';

  bool openNavigationDrawer = true;
  bool activeNearbyDriverKeysLoaded = true;

  // googlemap -> BitmapDescriptor
  BitmapDescriptor? activeNearbyIcon;

  DatabaseReference? referenceRideRequest;
  String selectedVehicleType = '';
  String driverRideStatus = 'Driver is coming';
  StreamSubscription<DatabaseEvent>? tripRidesRequestInfoStreamSubscription;
  List<ActiveNearByAvailableDrivers> onlineNearByAvailableDriversList = [];
  String userRideRequestStatus = '';
  bool requestPositionInfo = true;
  // NotificationService notificationService = NotificationService();

  // geolocator로 현재 좌표 가져오기
  locateUserPosition() async {
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 15);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoordinates(userCurrentPosition!, context);
    print('출발지 주소 : ${humanReadableAddress}');

    userName = userModelCurrentInfo!.name!;
    userEmail = userModelCurrentInfo!.email!;

    initializeGeoFireListener();

    AssistantMethods.readTripKeysForOnlineUser(context);
  }

  initializeGeoFireListener() {
    Geofire.initialize('activeDrivers');

    Geofire.queryAtLocation(userCurrentPosition!.latitude, userCurrentPosition!.longitude, 10)!
    .listen((map) {
      print(map);

      if (map != null) {
        var callBack = map['callBack'];

        switch (callBack) {
          // whenever any driver become active/online
          case Geofire.onKeyEntered:
            ActiveNearByAvailableDrivers activeNearByAvailableDrivers = ActiveNearByAvailableDrivers();
            activeNearByAvailableDrivers.locationLatitude = map['latitude'];
            activeNearByAvailableDrivers.locationLongitude = map['longitude'];
            activeNearByAvailableDrivers.driverId = map['key'];

            GeoFireAssistant.activeNearByAvailableDriversList.add(activeNearByAvailableDrivers);

            if (activeNearbyDriverKeysLoaded) {
              displayActiveDriversOnUsersMap();
            }

            break;
          // whenever any driver become non-active/online
          case Geofire.onKeyExited:
            GeoFireAssistant.deleteOfflineDriverFromList(map['key']);
            displayActiveDriversOnUsersMap();
            break;
          // whenever driver moves - update driver location
          case Geofire.onKeyMoved:
            ActiveNearByAvailableDrivers activeNearByAvailableDrivers = ActiveNearByAvailableDrivers();
            activeNearByAvailableDrivers.locationLatitude = map['latitude'];
            activeNearByAvailableDrivers.locationLongitude = map['longitude'];
            activeNearByAvailableDrivers.driverId = map['key'];

            GeoFireAssistant.updateActiveNearByAvailableDriverLocation(activeNearByAvailableDrivers);
            displayActiveDriversOnUsersMap();
            break;
          // display those online actie drivers on user's map
          case Geofire.onGeoQueryReady:
            activeNearbyDriverKeysLoaded = true;
            displayActiveDriversOnUsersMap();
            break;
        }
      }

      setState(() {

      });

    });
  }

  displayActiveDriversOnUsersMap() {
    setState(() {
      markersSet.clear();
      circlesSet.clear();

      Set<Marker> driversMarkerSet = Set<Marker>();

      for (ActiveNearByAvailableDrivers eachDriver in GeoFireAssistant.activeNearByAvailableDriversList) {
        LatLng eachDriverActivePosition = LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);

        Marker marker = Marker(
            markerId: MarkerId(eachDriver.driverId!),
            position: eachDriverActivePosition,
            icon: activeNearbyIcon!,
            rotation: 360,
        );

        driversMarkerSet.add(marker);
      }

      setState(() {
        markersSet = driversMarkerSet;
      });
    });
  }

  createActiveNearByDriverIconMarker() {
    if (activeNearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: Size(2, 2));
      BitmapDescriptor.fromAssetImage(imageConfiguration, 'images/car.png').then ((value) {
        activeNearbyIcon = value;
      });
    }
  }

  Future<void> drawPolyLineFromOriginToDestination(bool darkTheme) async {
    var originPosition = Provider.of<AppInfo>(context, listen: false).userPickUpLocation;
    var destinationPosition = Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

    var originLatLng = LatLng(originPosition!.locationLatitude!, originPosition.locationLongitude!);
    var destinationLatLng = LatLng(destinationPosition!.locationLatitude!, destinationPosition.locationLongitude!);

    showDialog(
        context: context,
        builder: (BuildContext context) => ProgressDialog(message: '경로탐색 중',),
    );

    var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(originLatLng, destinationLatLng);
    setState(() {
      tripDirectionDetailsInfo = directionDetailsInfo;
    });

    Navigator.pop(context);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodePolyLinePointsResultList = pPoints.decodePolyline(directionDetailsInfo.e_points!);

    print('decodePolyLinePointsResultList : ${decodePolyLinePointsResultList}');
    pLineCoordinatedList.clear();

    if (decodePolyLinePointsResultList.isNotEmpty) {
      decodePolyLinePointsResultList.forEach( (PointLatLng pointLatLng) {
        pLineCoordinatedList.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    print('pLineCoordinatedList : ${pLineCoordinatedList}');

    polylineSet.clear();

    setState(() {
      Polyline polyline = Polyline(
        color: darkTheme ? Colors.amberAccent : Colors.blue,
        polylineId: PolylineId('PolylineID'),
        jointType: JointType.round,
        points: pLineCoordinatedList,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        width: 5
      );

      polylineSet.add(polyline);
      print('polylineSet : ${polylineSet}');
    });

    LatLngBounds boundsLatLng;

    if (originLatLng.latitude > destinationLatLng.latitude && originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng =
          LatLngBounds(southwest: destinationLatLng, northeast: originLatLng);
    }
    else if (originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
        northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude),
      );
    }
    else if (originLatLng.latitude > destinationLatLng.latitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
        northeast: LatLng(originLatLng.latitude, destinationLatLng.longitude),
      );
    }
    else {
      boundsLatLng = LatLngBounds(southwest: originLatLng, northeast: destinationLatLng);
    }

    newGoogleMapController!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 65));

    Marker originMarker = Marker(
      markerId: MarkerId('originID'),
      infoWindow: InfoWindow(title: originPosition.locationName, snippet: 'Origin'),
      position: originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    Marker destinationMarker = Marker(
      markerId: MarkerId('destinationID'),
      infoWindow: InfoWindow(title: destinationPosition.locationName, snippet: 'Destination'),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      markersSet.add(originMarker);
      markersSet.add(destinationMarker);
    });

    Circle originCircle = Circle(
      circleId: CircleId('originID'),
      fillColor: Colors.green,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: originLatLng,
    );

    Circle destinationCircle = Circle(
      circleId: CircleId('destinationID'),
      fillColor: Colors.red,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: destinationLatLng,
    );

    setState(() {
      circlesSet.add(originCircle);
      circlesSet.add(destinationCircle);
    });
  }

  void showSuggestedRidesContainer() {
    setState(() {
      suggestedRidesContainerHeight = 400;
      bottomPaddingOfMap = 400;
    });
  }

  void showSearchingForDriversContainer() {
    setState(() {
      searchingForDriverContainerHeight = 200;
    });
  }

  // getAddressFromLatLng() async {
  //   try {
  //     GeoData data = await Geocoder2.getDataFromCoordinates(
  //       latitude: pickLocation!.latitude,
  //       longitude: pickLocation!.longitude,
  //       googleMapApiKey: mapKey,
  //     );
  //
  //     setState(() {
  //       Directions userPickUpAddress = Directions();
  //       userPickUpAddress.locationLatitude = pickLocation!.latitude;
  //       userPickUpAddress.locationLongitude = pickLocation!.longitude;
  //       userPickUpAddress.locationName = data.address;
  //
  //       Provider.of<AppInfo>(context, listen: false).updatePickUpLocationAddress(userPickUpAddress);
  //       // _address = data.address;
  //     });
  //   } catch(e) {
  //     print(e);
  //   }
  // }

  checkIfLocationPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();

    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  saveRideRequestInformation(String selectedVehicleType) {
      // 1. 여정호출정보 저장
      referenceRideRequest = FirebaseDatabase.instance.ref().child('All Ride Requests').push();

      var originLocation = Provider.of<AppInfo>(context, listen: false).userPickUpLocation;
      var destinationLocation = Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

      Map originLocationMap = {
        // 'key': 'value',
        'latitude': originLocation!.locationLatitude.toString(),
        'longitude': originLocation.locationLongitude.toString(),
      };

      Map destinationLocationMap = {
        // 'key': 'value',
        'latitude': destinationLocation!.locationLatitude.toString(),
        'longitude': destinationLocation.locationLongitude.toString(),
      };

      Map userInformationMap = {
        'origin': originLocationMap,
        'destination': destinationLocationMap,
        'time': DateTime.now().toString(),
        'userName': userModelCurrentInfo!.name,
        'userPhone': userModelCurrentInfo!.phone,
        'originAddress': originLocation.locationName,
        'destinationAddress': destinationLocation.locationName,
        'driverId': 'waiting'
      };

      referenceRideRequest!.set(userInformationMap);

      tripRidesRequestInfoStreamSubscription = referenceRideRequest!.onValue.listen((eventSnap) async {
        if (eventSnap.snapshot.value == null) {
          return;
        }

        if ((eventSnap.snapshot.value as Map)['car_details'] != null) {
          setState(() {
            driverCarDetails = (eventSnap.snapshot.value as Map)['car_details'].toString();
          });
        }

        if ((eventSnap.snapshot.value as Map)['driverPhone'] != null) {
          setState(() {
            driverPhone = (eventSnap.snapshot.value as Map)['driverPhone'].toString();
          });
        }

        if ((eventSnap.snapshot.value as Map)['driverName'] != null) {
          setState(() {
            driverName = (eventSnap.snapshot.value as Map)['driverName'].toString();
          });
        }

        if ((eventSnap.snapshot.value as Map)['ratings'] != null) {
          setState(() {
            driverRatings = (eventSnap.snapshot.value as Map)['ratings'].toString();
          });
        }

        if ((eventSnap.snapshot.value as Map)['status'] != null) {
          setState(() {
            userRideRequestStatus = (eventSnap.snapshot.value as Map)['status'].toString();
          });
        }

        if ((eventSnap.snapshot.value as Map)['driverLocation'] != null) {
          double driverCurrentPositionLat = double.parse(
              (eventSnap.snapshot.value as Map)['driverLocation']['latitude']
                  .toString());
          double driverCurrentPositionLng = double.parse(
              (eventSnap.snapshot.value as Map)['driverLocation']['longitude']
                  .toString());

          LatLng driverCurrentPositionLatLng = LatLng(driverCurrentPositionLat, driverCurrentPositionLat);


          // status == accepted
          if (userRideRequestStatus == 'accepted') {
            updateArrivalTimeToUserPickUpLocation(driverCurrentPositionLatLng);
          }

          // status == arrived
          if (userRideRequestStatus == 'arrived') {
            setState(() {
              driverRideStatus = 'Driver has arrived';
            });
          }

          // status = ontrip
          if (userRideRequestStatus == 'ontrip') {
            updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng);
          }

          if (userRideRequestStatus == 'ended') {
            if ((eventSnap.snapshot.value as Map)['fareAmount'] != null) {
              double fareAmount = double.parse((eventSnap.snapshot.value as Map)['fareAmount'].toString());

              var response = await showDialog(
                  context: context,
                  builder: (BuildContext context) => PayFareAmountDialog(
                    fareAmount: fareAmount,
                  )
              );

              if (response == 'Cash Paid') {
                // user can rate the driver now
                if ((eventSnap.snapshot.value as Map)['driverId'] != null) {
                  String assignedDriverId = (eventSnap.snapshot.value as Map)['driverId'].toString();
                  Navigator.push(context, MaterialPageRoute(builder: (c) => RateDriverScreen(
                    assignedDriverId: assignedDriverId
                  )));

                  referenceRideRequest!.onDisconnect();
                  tripRidesRequestInfoStreamSubscription!.cancel();
                }
              }
            }
          }
        }

      });

      onlineNearByAvailableDriversList = GeoFireAssistant.activeNearByAvailableDriversList;
      searchNearestOnlineDrivers(selectedVehicleType);
  }

  searchNearestOnlineDrivers(String selectedVehicleType) async {
    if (onlineNearByAvailableDriversList.length == 0) {
      // cancel/delete the rideRequest Information
      referenceRideRequest!.remove();

      setState(() {
        polylineSet.clear();
        markersSet.clear();
        circlesSet.clear();
        pLineCoordinatedList.clear();
      });

      Fluttertoast.showToast(msg: 'No online nearst Driver Available');
      Fluttertoast.showToast(msg: 'Search Again. \n Restarting App');

      Future.delayed(Duration(milliseconds: 4000), () {
        referenceRideRequest!.remove();
        Navigator.push(context, MaterialPageRoute(builder: (c) => SplashScreen()));
      });

      return;
    }

    await retrieveOnlineDriversInformation(onlineNearByAvailableDriversList);

    print('Driver List: ' + driversList.toString());

    for(int i = 0; i < driversList.length; i++) {
      if (driversList[i]['car_details']['type'] == selectedVehicleType) {
        AssistantMethods.sendNotificationToDriverNow(driversList[i]['token'], referenceRideRequest!.key!, context);
        // notificationService.sendNotificationToDriverNow(driversList[i]['token'], referenceRideRequest!.key!, context);
      }
    }

    Fluttertoast.showToast(msg: 'Notification sent Successful');

    showSearchingForDriversContainer();
    
    await FirebaseDatabase.instance.ref().child('All Ride Requests').child(referenceRideRequest!.key!).child('driverId').onValue.listen((eventRideRequestSnapshot) {
      print('EventSnapshot: ${eventRideRequestSnapshot.snapshot.value}');

      if (eventRideRequestSnapshot.snapshot.value != null) {
        if (eventRideRequestSnapshot.snapshot.value != 'waiting') {
          showUIForAssignedDriverInfo();
        }
      }
    });
  }

  updateArrivalTimeToUserPickUpLocation(driverCurrentPositionLatLng) async {
    if (requestPositionInfo) {
      requestPositionInfo = false;
      LatLng userPickUpPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);

      var directionDetailsinfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(driverCurrentPositionLatLng, userPickUpPosition);

      if (directionDetailsinfo == null) {
        return;
      }

      setState(() {
        driverRideStatus = 'Driver is coming: ' + directionDetailsinfo.duration_text.toString();
      });

      requestPositionInfo =  true;
    }
  }

  updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng) async {
    if (requestPositionInfo) {
      requestPositionInfo = false;

      var dropOffLocation = Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

      LatLng userDestinationPosition = LatLng(
          dropOffLocation!.locationLatitude!,
          dropOffLocation.locationLongitude!,
      );

      var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(driverCurrentPositionLatLng, userDestinationPosition);

      if (directionDetailsInfo == null) {
        return;
      }

      setState(() {
        driverRideStatus = 'Going Towards Destination: ' + directionDetailsInfo.duration_text.toString();
      });

      requestPositionInfo = true;
    }
  }

  showUIForAssignedDriverInfo() {
    setState(() {
      waitingResponsefromDriverContainerHeight = 0;
      searchLocationContainerHeight = 0;
      assignedDriverInfoContainerHeight = 200;
      suggestedRidesContainerHeight = 0;
      bottomPaddingOfMap = 200;
    });
  }

  retrieveOnlineDriversInformation(List onlineNearestDriversList) async {
    driversList.clear();
    DatabaseReference ref = FirebaseDatabase.instance.ref().child('drivers');

    for(int i = 0;i < onlineNearestDriversList.length; i ++) {
      await ref.child(onlineNearestDriversList[i].driverId.toString()).once().then((dataSnapshot) {
        var driverKeyInfo = dataSnapshot.snapshot.value;

        driversList.add(driverKeyInfo);
        print('driver key information = ' + driversList.toString());
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // notificationService.requestNotificationPermission();
    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    createActiveNearByDriverIconMarker();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _scaffoldState,
        drawer: DrawerScreen(),
        body: Stack(
          children: [
            GoogleMap(
              padding: EdgeInsets.only(top: 30, bottom: bottomPaddingOfMap),
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: _kGooglePlex,
              polylines: polylineSet,
              markers: markersSet,
              circles: circlesSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;

                setState(() {
                  bottomPaddingOfMap = 200;
                });

                locateUserPosition();
              },
              /* 카메라 이동 - 홈화면에 출발지 표시하려면
              onCameraMove: (CameraPosition? position) {
                if (pickLocation != position!.target) {
                  setState(() {
                    pickLocation = position.target;
                  });
                }
              },
              */
              /* 카메라 이동 완료 후 - 홈화면에 출발지 표시하려면
              onCameraIdle: () {
                getAddressFromLatLng();
              },
               */
            ),
            
            // Align(
            //   alignment: Alignment.center,
            //   child: Padding(
            //     padding: EdgeInsets.only(bottom: bottomPaddingOfMap),
            //     child: Image.asset('images/icn_pick_purple.png', height: 150, width: 150,),
            //   ),
            // ),

            // custom side menu button for drawer
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                child: GestureDetector(
                  onTap: () {
                    _scaffoldState.currentState!.openDrawer();
                  },
                  child: CircleAvatar(
                    backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.white,
                    child: Icon(
                      Icons.menu,
                      color: darkTheme ? Colors.black : Colors.lightBlue,
                    ),
                  ),
                ),
              ),
            ),

            // UI for Searching Location
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 50, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: darkTheme ? Colors.black : Colors.white, // 5편 태ㅜㄱinwegrey.shade900, EdgeInsets 없음
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(5),
                            child: Row(
                              children: [
                                Icon(
                                    Icons.location_on_outlined,
                                    color: darkTheme ? Colors.amber.shade400 : Colors.blue
                                ),
                                SizedBox(width: 10,),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '출발지',
                                      style: TextStyle(
                                        color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    Text(
                                      Provider.of<AppInfo>(context).userPickUpLocation != null ?
                                      (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0, 24) + '...' :
                                      '출발지를 가져올 수 없습니다.',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),

                          SizedBox(height: 5,),

                          Divider(
                            height: 1,
                            thickness: 2,
                            color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                          ),

                          SizedBox(height: 5,),

                          Padding(
                              padding: EdgeInsets.all(5),
                            child: GestureDetector(
                              onTap: () async {
                                var responseFromSearchScreen = await Navigator.push(context, MaterialPageRoute(builder: (c) => SearchPlacesScreen()));

                                if (responseFromSearchScreen == 'obtainedDropOff') {
                                  setState(() {
                                    openNavigationDrawer = false;
                                  });

                                  await drawPolyLineFromOriginToDestination(darkTheme);
                                }

                              },
                              child: Row(
                                children: [
                                  Icon(
                                      Icons.location_on_outlined,
                                      color: darkTheme ? Colors.amber.shade400 : Colors.blue
                                  ),
                                  SizedBox(width: 10,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '도착지',
                                        style: TextStyle(
                                            color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      Text(
                                        Provider.of<AppInfo>(context).userDropOffLocation != null ?
                                        Provider.of<AppInfo>(context).userDropOffLocation!.locationName! :
                                        '어디로 가시나요?',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),

                    SizedBox(height: 5,),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => PrecisePickupLocation()));
                            },
                            child: Text(
                              '출발지 설정',
                              style: TextStyle(
                                color: darkTheme ? Colors.black : Colors.white,
                              ),
                            ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue,
                            textStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            )
                          ),
                        ),

                        SizedBox(width: 10,),

                        ElevatedButton(
                          onPressed: () {
                            if (Provider.of<AppInfo>(context, listen: false).userDropOffLocation != null) {
                              showSuggestedRidesContainer();
                            }
                            else {
                              Fluttertoast.showToast(msg: '도착지를 설정해주세요');
                            }
                          },
                          child: Text(
                            '요금 선택',
                            style: TextStyle(
                              color: darkTheme ? Colors.black : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue,
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )
                          ),
                        ),

                      ],
                    ),

                  ],
                ),
              ),
            ),

            // ui for suggested rides
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: suggestedRidesContainerHeight,
                  decoration: BoxDecoration(
                    color: darkTheme ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      topLeft: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Icon(
                                Icons.star,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(width: 15,),

                            Text(
                              Provider.of<AppInfo>(context).userPickUpLocation != null ?
                              (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0, 24) + '...' :
                              '출발지를 가져올 수 없습니다.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20,),

                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Icon(
                                Icons.star,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(width: 15,),

                            Text(
                              Provider.of<AppInfo>(context).userDropOffLocation != null ?
                              (Provider.of<AppInfo>(context).userDropOffLocation!.locationName!) :
                              '어디로 가시나요?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20,),

                        Text(
                          '예상 요금',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 20,),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedVehicleType = 'Car';
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == 'Car' ? (darkTheme ? Colors.amber.shade400 : Colors.blue) : (darkTheme ? Colors.black54 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                    padding: EdgeInsets.all(25.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.directions_car,),
                                      SizedBox(height: 8,),
                                      Text(
                                        'Car',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedVehicleType == 'Car' ? (darkTheme ? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        )
                                      ),
                                      SizedBox(height: 2,),
                                      Text(tripDirectionDetailsInfo != null ?
                                      '\$ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 2) * 107).toStringAsFixed(1)}' : 'null',
                                        style:
                                        TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedVehicleType = 'CNG';
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == 'CNG' ? (darkTheme ? Colors.amber.shade400 : Colors.blue) : (darkTheme ? Colors.black54 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(25.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.train,),
                                      SizedBox(height: 8,),
                                      Text(
                                          'CNG',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selectedVehicleType == 'CNG' ? (darkTheme ? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                          )
                                      ),
                                      SizedBox(height: 2,),
                                      Text(tripDirectionDetailsInfo != null ?
                                      '\$ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 1.5) * 107).toStringAsFixed(1)}' : 'null',
                                        style:
                                        TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedVehicleType = 'Bike';
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == 'Bike' ? (darkTheme ? Colors.amber.shade400 : Colors.blue) : (darkTheme ? Colors.black54 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(25.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.electric_bike,),

                                      SizedBox(height: 8,),
                                      Text(
                                          'Bike',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selectedVehicleType == 'Bike' ? (darkTheme ? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                          )
                                      ),
                                      SizedBox(height: 2,),
                                      Text(tripDirectionDetailsInfo != null ?
                                      '\$ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 0.8) * 107).toStringAsFixed(1)}' : 'null',
                                        style:
                                        TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20,),

                        Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (selectedVehicleType != '') {
                                  saveRideRequestInformation(selectedVehicleType);
                                }
                                else {
                                  Fluttertoast.showToast(msg: '차종을 선택해주세요');
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '호출하기',
                                    style: TextStyle(
                                      color: darkTheme ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            )
                        ),

                      ],
                    ),
                  ),
                )
            ),

            //  Requesting a ride
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: searchingForDriverContainerHeight,
                  decoration: BoxDecoration(
                    color: darkTheme ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        LinearProgressIndicator(
                          color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                        ),

                        SizedBox(height: 10,),

                        Center(
                          child: Text(
                            '기사를 찾는 중 ...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),

                        SizedBox(height: 20,),

                        GestureDetector(
                          onTap: () {
                            referenceRideRequest!.remove();
                            setState(() {
                              searchingForDriverContainerHeight = 0;
                              suggestedRidesContainerHeight = 0;
                            });
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: darkTheme ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(width: 1, color: Colors.grey),
                            ),
                            child: Icon(Icons.close, size: 25,),
                          ),
                        ),

                        SizedBox(height: 15,),

                        Container(
                          width: double.infinity,
                          child: Text(
                            '취소',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),


                      ],
                    ),
                  ),
                )
            ),

            // UI For displaying assigned driver information
            Positioned(
              bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: assignedDriverInfoContainerHeight,
                  decoration: BoxDecoration(
                    color: darkTheme ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Text(driverRideStatus, style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 5,),
                        Divider(thickness: 1, color: darkTheme ? Colors.grey : Colors.grey.shade300),
                        SizedBox(height: 5,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: darkTheme ? Colors.amber.shade400 : Colors.lightBlue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.person, color: darkTheme ? Colors.black : Colors.white,),
                                ),

                                SizedBox(width: 10,),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(driverName, style: TextStyle(fontWeight: FontWeight.bold),),

                                    Row(
                                      children: [
                                      Icon(Icons.star, color: Colors.orange,),
                                        SizedBox(width: 5,),

                                        Text(
                                          '4.00',
                                          style: TextStyle(color: Colors.grey),)
                                    ],)
                                  ],
                                )
                              ],
                            ),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Image.asset('images/car.png', scale: 3,),
                                Text(driverCarDetails, style: TextStyle(fontSize: 12),)
                              ],
                            ),


                          ],
                        ),

                        SizedBox(height: 5,),
                        Divider(thickness: 1, color: darkTheme ? Colors.grey : Colors.grey.shade300),
                        ElevatedButton.icon(
                            onPressed: () {
                              _makePhoneCall('tel: ${driverPhone}');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue),
                            icon: Icon(Icons.phone),
                            label: Text('Call Driver')
                        ),
                      ],
                    ),
                  ),
                )
            ),

            /* 출발지 주소표시 - 홈화면에 출발지 표시하려면
            Positioned(
              top: 40,
              right: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  color: Colors.white
                ),
                padding: EdgeInsets.all(20),
                child: Text(
                  Provider.of<AppInfo>(context).userPickUpLocation != null ?
                  (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0, 24) + '...' :
                  '출발지를 가져올 수 없습니다.',
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ),
            */

          ],
        ),
      ),
    );
  }
}
