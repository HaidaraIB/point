import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

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
           return Builder(
             builder: (context) {
               final theme = context.appTheme;
               final resolvedFill = fillColor ?? theme.inputFill;
               final resolvedBorder = borderColor ?? theme.border;
               final fieldText = context.textOnFill(resolvedFill);
               final fieldHint = context.hintOnFill(resolvedFill);

               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (label != null) ...[
                     const SizedBox(height: 15),
                     Row(
                       children: [
                         Text(
                           label,
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 12,
                             color: theme.primaryText,
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
                       color: resolvedFill,
                       borderRadius: BorderRadius.circular(borderRadius ?? 15),
                       border: Border.all(color: resolvedBorder),
                     ),
                     child: DropdownButtonHideUnderline(
                       child: DropdownButton<T>(
                         isExpanded: true,
                         value: null,
                         dropdownColor: theme.cardSurface,
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
                                 state.value!.isEmpty ? fieldHint : fieldText,
                           ),
                         ),
                         icon: Icon(
                           Icons.keyboard_arrow_down_rounded,
                           color: theme.mutedText,
                         ),
                         style: TextStyle(fontSize: 13, color: theme.primaryText),
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
                                             ? AppColors.primary.withValues(
                                               alpha: 0.2,
                                             )
                                             : Colors.transparent,
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: Text(
                                     itemLabel != null
                                         ? itemLabel(item)
                                         : item.toString(),
                                     style: TextStyle(
                                       fontSize: 13,
                                       color: theme.primaryText,
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
         },
       );
}
