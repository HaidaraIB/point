import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';

class DynamicDropdownMultiSelect<T> extends FormField<List<T>> {
  DynamicDropdownMultiSelect({
    super.key,
    required List<T> items,
    required List<T> selectedValues,
    required void Function(List<T>) onChanged,
    String Function(T)? itemLabel,
    String? label,
    String? hint,
    Color? borderColor,
    double? borderRadius,
    Color? fillColor,
    bool? require,
    double? height,
    String? Function(List<T>?)? validator,
  }) : super(
         initialValue: selectedValues,
         validator: validator,
         builder: (state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               if (label != null) ...[
                 const SizedBox(height: 15),
                 Row(
                   children: [
                     Text(
                       label,
                       style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 12,
                       ),
                     ),
                     if (require == true)
                       const Text(" * ", style: TextStyle(color: Colors.red)),
                   ],
                 ),
                 const SizedBox(height: 8),
               ],
               Container(
                 height: height ?? 50,
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 decoration: BoxDecoration(
                   color: fillColor ?? Colors.white,
                   borderRadius: BorderRadius.circular(borderRadius ?? 15),
                   border: Border.all(
                     color: borderColor ?? const Color(0xffF1F5F9),
                   ),
                 ),
                 child: DropdownButtonHideUnderline(
                   child: DropdownButton<T>(
                     isExpanded: true,
                     value: null, // null عشان تفتح كل العناصر
                     hint: Text(
                       state.value!.isEmpty
                           ? hint ?? ""
                           : state.value!
                               .map(
                                 (e) =>
                                     itemLabel != null
                                         ? itemLabel(e)
                                         : e.toString(),
                               )
                               .join(", "),
                       overflow: TextOverflow.ellipsis,
                       style: TextStyle(
                         fontSize: 13,
                         color:
                             state.value!.isEmpty
                                 ? Colors.grey
                                 : AppColors.primaryfontColor,
                       ),
                     ),
                     icon: const Icon(
                       Icons.keyboard_arrow_down_rounded,
                       color: Colors.grey,
                     ),
                     items:
                         items.map((item) {
                           final bool selected = state.value!.contains(item);
                           return DropdownMenuItem<T>(
                             value: item,
                             child: Container(
                               padding: const EdgeInsets.symmetric(
                                 vertical: 4,
                                 horizontal: 8,
                               ),
                               decoration: BoxDecoration(
                                 color:
                                     selected
                                         ? AppColors.primary.withValues(alpha: 0.2)
                                         : Colors.transparent,
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: Text(
                                 itemLabel != null
                                     ? itemLabel(item)
                                     : item.toString(),
                                 style: TextStyle(
                                   fontSize: 13,
                                   color:
                                       selected
                                           ? AppColors.primaryfontColor
                                           : Colors.black,
                                 ),
                               ),
                             ),
                           );
                         }).toList(),
                     onChanged: (T? value) {
                       if (value == null) return;
                       final newList = List<T>.from(state.value!);
                       if (newList.contains(value)) {
                         newList.remove(value);
                       } else {
                         newList.add(value);
                       }
                       state.didChange(newList);
                       onChanged(newList);
                     },
                   ),
                 ),
               ),
               if (state.hasError)
                 Padding(
                   padding: const EdgeInsets.only(top: 5, left: 5),
                   child: Text(
                     state.errorText!,
                     style: const TextStyle(color: Colors.red, fontSize: 12),
                   ),
                 ),
             ],
           );
         },
       );
}
