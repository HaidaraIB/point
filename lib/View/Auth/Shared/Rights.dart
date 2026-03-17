import 'package:flutter/material.dart';

Widget buildRightsSection() {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '© 2025 Point. جميع الحقوق محفوظة',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}
