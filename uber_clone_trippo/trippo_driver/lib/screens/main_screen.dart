import 'package:flutter/material.dart';
import 'package:trippo_driver/global/global.dart';
import 'package:trippo_driver/screens/splashScreen/splash_screen.dart';

import '../tabPages/earning_tab.dart';
import '../tabPages/home_tab.dart';
import '../tabPages/profile_tab.dart';
import '../tabPages/ratings_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {

  TabController? tabController;
  int selectedIndex = 0;

  onItemClicked(int index) {
    setState(() {
      selectedIndex = index;
      tabController!.index = selectedIndex;
    });
  }

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {

    bool darkTheme = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      body: TabBarView(
        physics: NeverScrollableScrollPhysics(),
          controller: tabController,
          children: [
            HomeTabPage(),
            EarningsTabPage(),
            RatingsTabPage(),
            ProfileTabPage(),
          ]
      ),

      bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "홈"),
            BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: "수익"),
            BottomNavigationBarItem(icon: Icon(Icons.star), label: "평가"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "계정"),
          ],
        unselectedItemColor: darkTheme ? Colors.black54 : Colors.white54,
        selectedItemColor: darkTheme ? Colors.black : Colors.white,
        backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 14),
        showUnselectedLabels: true,
        currentIndex: selectedIndex,
        onTap: onItemClicked,
      ),
    );
  }
}
