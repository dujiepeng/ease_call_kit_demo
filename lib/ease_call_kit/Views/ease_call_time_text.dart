import 'package:flutter/widgets.dart';

class EaseCallTimeText extends StatefulWidget {
  const EaseCallTimeText(
    this.curStr,
    this.textStyle, {
    Key? key,
  }) : super(key: key);

  final TextStyle textStyle;
  final String curStr;
  @override
  EaseCallTimeTextState createState() => EaseCallTimeTextState();
}

class EaseCallTimeTextState extends State<EaseCallTimeText> {
  String? timeStr;
  @override
  Widget build(BuildContext context) {
    return Text(
      timeStr ?? widget.curStr,
      style: widget.textStyle,
    );
  }

  void strUpdate(String str) {
    setState(() {
      timeStr = str;
    });
  }
}
