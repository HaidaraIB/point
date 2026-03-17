import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

class DynamicMultiSelect<T> extends StatefulWidget {
  final String? label;
  final String? hint;
  final List<T> items;
  final List<T> selectedValues;
  final String Function(T)? itemLabel;
  final double radius;
  final bool? require;
  final Color? borderColor;
  final Color? fillColor;
  final double? borderRadius;
  final double? height;
  final String? Function(List<T>?)? validator;
  final void Function(List<T>) onChanged;

  DynamicMultiSelect({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.label,
    this.hint,
    this.itemLabel,
    this.borderColor,
    this.borderRadius,
    this.height,
    this.radius = 12,
    this.fillColor,
    this.require,
    this.validator,
  });

  @override
  State<DynamicMultiSelect<T>> createState() => _DynamicMultiSelectState<T>();
}

class _DynamicMultiSelectState<T> extends State<DynamicMultiSelect<T>> {
  late List<T> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedValues);
  }

  void _showMultiSelectDialog() async {
    final List<T> tempList = List.from(_selectedItems);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, nsetState) => Container(
                padding: EdgeInsets.all(16),
                height: Get.height * 0.7,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final label =
                              widget.itemLabel != null
                                  ? widget.itemLabel!(item)
                                  : item.toString();

                          final isSelected = tempList.contains(item);

                          return InkWell(
                            onTap: () {
                              nsetState(() {
                                if (!isSelected) {
                                  tempList.add(item);
                                } else {
                                  tempList.remove(item);
                                }
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.all(5),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isSelected ? Colors.grey.shade300 : null,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label.toString().tr,
                                    style: TextStyle(
                                      color: AppColors.fontColorGrey,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check, color: Colors.green),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: Get.width * 0.4 - 260,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF5C5589),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 20,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selectedItems = List.from(tempList));
                          widget.onChanged(_selectedItems);
                          Navigator.pop(context);
                        },
                        child: Text(
                          "حفظ",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final selectedText =
            _selectedItems.isEmpty
                ? (widget.hint ?? '')
                : _selectedItems
                    .map(
                      (e) =>
                          widget.itemLabel != null
                              ? widget.itemLabel!(e)
                              : e.toString(),
                    )
                    .join(', ');

        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),

              if (widget.label != null)
                Row(
                  children: [
                    Text(
                      widget.label!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.require == true)
                      Text(' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showMultiSelectDialog,
                child: Container(
                  height: widget.height ?? 45,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: widget.borderColor ?? Color(0xffF1F5F9),
                    ),
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius ?? 15,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedText.isEmpty
                              ? widget.hint ?? ''
                              : selectedText,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                selectedText.isEmpty
                                    ? Colors.grey
                                    : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
