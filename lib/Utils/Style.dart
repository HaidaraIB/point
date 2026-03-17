import 'package:flutter/material.dart';

class Style {
  static final roundedContainerRadius = BoxDecoration(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.grey.shade200,
        blurRadius: 10,
        offset: Offset(0, -4),
      ),
    ],
  );
}
