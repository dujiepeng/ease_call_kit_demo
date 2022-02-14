import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';

class EaseCallError {
  final int errCode;
  final EaseCallErrorType errType;
  final String errDesc;

  EaseCallError(this.errCode, this.errType, this.errDesc);
}

class EaseCallProcessErrorCode {
  static const int invalidParams = 100;
  static const int currBusy = 101;
  static const int fetchTokenFail = 102;
}
