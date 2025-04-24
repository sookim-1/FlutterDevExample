
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trippo_user/models/direction_details_info.dart';
import '../models/user_model.dart';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
User? currentUser;

UserModel? userModelCurrentInfo;

List driversList = [];
DirectionDetailsInfo? tripDirectionDetailsInfo;
String userDropOffAddress = '';
String driverCarDetails = '';
String driverName = '';
String driverPhone = '';
String driverRatings = '';


double countRatingStars = 0.0;
String titleStarsRating = '';