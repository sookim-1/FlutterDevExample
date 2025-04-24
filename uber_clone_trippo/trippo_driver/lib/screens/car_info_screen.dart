import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:trippo_driver/screens/splashScreen/splash_screen.dart';

import '../global/global.dart';
import 'forgot_password_screen.dart';

class CarInfoScreen extends StatefulWidget {
  const CarInfoScreen({super.key});

  @override
  State<CarInfoScreen> createState() => _CarInfoScreenState();
}

class _CarInfoScreenState extends State<CarInfoScreen> {

  final carModelTextEditingController = TextEditingController();
  final carNumberTextEditingController = TextEditingController();
  final carColorTextEditingController = TextEditingController();

  List<String> carTypes = ['Car', 'CNG', 'Bike'];
  String? selectedCarType;

  final _formKey = GlobalKey<FormState>();

  void _submit() async {
    // 모든 입력값 검증
    if (_formKey.currentState!.validate()) {
      Map driverCarInfoMap = {
        'car_model': carModelTextEditingController.text.trim(),
        'car_number': carNumberTextEditingController.text.trim(),
        'car_color': carColorTextEditingController.text.trim(),
        'type': selectedCarType,
      };

      DatabaseReference userRef = FirebaseDatabase.instance.ref().child('drivers');
      userRef.child(currentUser!.uid).child('car_details').set(driverCarInfoMap);

      Fluttertoast.showToast(msg: '차량 정보 저장 성공');
      Navigator.push(context, MaterialPageRoute(builder: (c) => SplashScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.all(0),
          children: [
            Column(
              children: [
                Image.asset(darkTheme
                    ? 'images/img_logo_white.png'
                    : 'images/img_logo_purple.png'),

                SizedBox(height: 20,),

                Text(
                  '상세내역 추가',
                  style: TextStyle(
                    color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 20, 15, 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            TextFormField(
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(50)
                              ],
                              decoration: InputDecoration(
                                hintText: '자동차 모델',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: darkTheme
                                    ? Colors.black45
                                    : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide(
                                      width: 0,
                                      style: BorderStyle.none,
                                    )),
                                prefixIcon: Icon(
                                  Icons.car_crash,
                                  color: darkTheme
                                      ? Colors.amber.shade400
                                      : Colors.grey,
                                ),
                              ),
                              autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                              validator: (text) {
                                if (text == null || text.isEmpty) {
                                  return '자동차모델을 입력해주세요!';
                                }

                                if (text.length < 2) {
                                  return '유효하지 않은 자동차모델입니다.';
                                }

                                if (text.length > 49) {
                                  return '50자 미만으로 입력해주세요';
                                }
                              },
                              onChanged: (text) => setState(() {
                                carModelTextEditingController.text = text;
                              }),
                            ),

                            SizedBox(
                              height: 20,
                            ),

                            TextFormField(
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(50)
                              ],
                              decoration: InputDecoration(
                                hintText: '자동차 번호',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: darkTheme
                                    ? Colors.black45
                                    : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide(
                                      width: 0,
                                      style: BorderStyle.none,
                                    )),
                                prefixIcon: Icon(
                                  Icons.numbers,
                                  color: darkTheme
                                      ? Colors.amber.shade400
                                      : Colors.grey,
                                ),
                              ),
                              autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                              validator: (text) {
                                if (text == null || text.isEmpty) {
                                  return '자동차번호를 입력해주세요!';
                                }

                                if (text.length < 2) {
                                  return '유효하지 않은 자동차번호입니다.';
                                }

                                if (text.length > 49) {
                                  return '50자 미만으로 입력해주세요';
                                }
                              },
                              onChanged: (text) => setState(() {
                                carNumberTextEditingController.text = text;
                              }),
                            ),

                            SizedBox(
                              height: 20,
                            ),

                            TextFormField(
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(50)
                              ],
                              decoration: InputDecoration(
                                hintText: '자동차 색상',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: darkTheme
                                    ? Colors.black45
                                    : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide(
                                      width: 0,
                                      style: BorderStyle.none,
                                    )),
                                prefixIcon: Icon(
                                  Icons.color_lens,
                                  color: darkTheme
                                      ? Colors.amber.shade400
                                      : Colors.grey,
                                ),
                              ),
                              autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                              validator: (text) {
                                if (text == null || text.isEmpty) {
                                  return '자동차색상을 입력해주세요!';
                                }

                                if (text.length < 2) {
                                  return '유효하지 않은 자동차색상입니다.';
                                }

                                if (text.length > 49) {
                                  return '50자 미만으로 입력해주세요';
                                }
                              },
                              onChanged: (text) => setState(() {
                                carColorTextEditingController.text = text;
                              }),
                            ),

                            SizedBox(height: 20),

                            DropdownButtonFormField(
                              decoration: InputDecoration(
                                hintText: '차량타입을 선택하세요',
                                prefixIcon: Icon(
                                  Icons.car_crash,
                                  color: darkTheme ? Colors.amber.shade400 : Colors.grey,
                                ),
                                filled: true,
                                fillColor: darkTheme ? Colors.black45 : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(40),
                                  borderSide: BorderSide(
                                    width: 0,
                                    style: BorderStyle.none
                                  )
                                )
                              ),
                                items: carTypes.map((car) {
                                  return DropdownMenuItem(
                                      child: Text(
                                        car,
                                        style: TextStyle(color: Colors.grey),
                                      ) ,
                                      value: car,
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                setState(() {
                                  selectedCarType = newValue.toString();
                                });
                              }
                            ),

                            SizedBox(height: 20,),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkTheme
                                    ? Colors.amber.shade400
                                    : Colors.blue,
                                foregroundColor: darkTheme ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                minimumSize: Size(double.infinity, 50),
                              ),
                              onPressed: () {
                                _submit();
                              },
                              child: Text(
                                '등록하기',
                                style: TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

}
