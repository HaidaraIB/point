part of 'package:point/View/Home/Home.dart';

Widget _userTypeButton(BuildContext context, String label, String type, String selected) {
  final controller = Get.find<HomeController>();
  final isSelected = selected == type;

  return GestureDetector(
    onTap: () => controller.changeType(type),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          // width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        // color: isSelected ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // color: isSelected ? Colors.deepPurple : context.appTheme.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected ? Colors.deepPurple : context.appTheme.secondaryText,
            size: 22,
          ),
        ],
      ),
    ),
  );
}
