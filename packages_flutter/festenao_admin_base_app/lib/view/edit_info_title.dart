import 'package:festenao_admin_base_app/theme/theme.dart';
import 'package:flutter/material.dart';

const darkGrayColor = Color(0xFF444444);
// When the text is set
const textEditSetColor = darkGrayColor;

class EditInfoTile extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? labelText;
  final String? valueText;
  final Widget? trailing;

  // True if the data is set
  final bool? set;

  const EditInfoTile({
    super.key,
    this.onTap,
    this.onLongPress,
    this.labelText,
    this.valueText,
    this.set,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    var valueTextColor = (set ?? false) ? textEditSetColor : null;

    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (valueText != null)
                            Text(
                              valueText!,
                              style: infoValueTextStyle.copyWith(
                                color: valueTextColor,
                              ),
                            ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                //UnderlineWidget(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
