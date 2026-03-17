import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

class DynamicRadio<T> extends StatelessWidget {
  final T value;
  final Rx<T> groupValue;
  final String label;
  final void Function(T?)? onChanged;

  const DynamicRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.label,
    this.onChanged,
  });

  void _handleChanged(T? val) {
    if (val != null) {
      groupValue.value = val;
      onChanged?.call(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => RadioGroup<T>(
        groupValue: groupValue.value,
        onChanged: _handleChanged,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<T>(
              value: value,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
