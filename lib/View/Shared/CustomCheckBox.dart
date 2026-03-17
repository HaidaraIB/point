import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

class DynamicCheckbox extends StatelessWidget {
  final String label;
  final RxBool? rxValue;
  final bool? value;
  final void Function(bool?)? onChanged;
  final Color activeColor;
  final Color borderColor;
  final double borderRadius;

  const DynamicCheckbox({
    super.key,
    required this.label,
    this.rxValue,
    this.value,
    this.onChanged,
    this.activeColor = Colors.blue,
    this.borderColor = Colors.grey,
    this.borderRadius = 5,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildCheckbox(bool checked, void Function(bool?) onChanged) {
      return Row(
        // mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(borderRadius),
            //   border: Border.all(color: checked ? activeColor : borderColor),
            // ),
            child: Checkbox(
              value: checked,
              onChanged: onChanged,
              side: BorderSide(color: Colors.grey.shade300),
              activeColor: activeColor,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                side: BorderSide(color: Colors.grey.shade100, strokeAlign: 0.1),
              ),
              visualDensity: VisualDensity(horizontal: -4.0, vertical: -4.0),
            ),
          ),

          Text(label),
        ],
      );
    }

    if (rxValue != null) {
      return Obx(
        () => buildCheckbox(rxValue!.value, (val) {
          rxValue!.value = val ?? false;
        }),
      );
    } else {
      return buildCheckbox(value ?? false, onChanged ?? (_) {});
    }
  }
}
