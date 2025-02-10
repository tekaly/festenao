import 'package:festenao_admin_base_app/theme/color.dart';
import 'package:festenao_admin_base_app/theme/theme.dart';
import 'package:festenao_admin_base_app/view/edit_info_title.dart';
import 'package:festenao_common/data/calendar.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/material.dart';

import 'leading_trailing.dart';

class CalendarEditTile extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? labelText;
  final String? valueText;
  final bool? set;

  const CalendarEditTile(
      {super.key,
      this.onTap,
      this.labelText,
      this.valueText,
      this.set,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
                border: Border.all(color: colorAdminLightBlue),
                borderRadius: BorderRadius.circular(10)),
            child: EditInfoTile(
              trailing: CalendarEditTrailing(),
              set: set,
              onTap: onTap,
              onLongPress: onLongPress,
              labelText: labelText,
              valueText: valueText,
            ),
          ),
        ),
        if (labelText != null)
          Positioned(
            left: 32,
            top: -2,
            child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Text(' $labelText ', style: infoLabelTextStyle)),
          ),
      ],
    );
  }
}

class CalendarFormFieldTile extends FormField<DateTime?> {
  final ValueNotifier<CalendarDay?> valueNotifier;

  CalendarFormFieldTile(
      {super.key,
      required BuildContext context,
      required this.valueNotifier,
      String? labelText})
      : super(
            initialValue: valueNotifier.value?.dateTime,
            validator: (value) {
              if (value == null) {
                return textFieldCannotBeEmptyError;
              }
              return null;
            },
            builder: (state) {
              return ValueListenableBuilder<CalendarDay?>(
                  valueListenable: valueNotifier,
                  builder: (context, snapshot, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CalendarEditTile(
                          labelText: labelText,
                          valueText: valueNotifier.value == null
                              ? ''
                              : valueNotifier.value!.toString(),
                          onLongPress: () {
                            valueNotifier.value = null;
                            state.didChange(null);
                          },
                          onTap: () async {
                            var now = DateTime.now();
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: valueNotifier.value?.dateTime ??
                                    DateTime.now(),
                                initialDatePickerMode: DatePickerMode.day,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 10));
                            if (picked != null) {
                              valueNotifier.value =
                                  CalendarDay(dateTime: picked);
                              state.didChange(picked);
                            }
                          },
                        ),
                        if (state.hasError)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              state.errorText!,
                              style: errorTextStyle,
                            ),
                          ),
                      ],
                    );
                  });
            });
}

class CalendarEditTrailing extends IconLeading {
  CalendarEditTrailing({super.key})
      : super(
            iconData: Icons.calendar_today,
            color: colorAdminLightBlue,
            size: editIconSize);
}
