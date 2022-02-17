import 'dart:async';
import 'dart:math';

import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_ec_call.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_error.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';

import 'package:im_flutter_sdk/im_flutter_sdk.dart';

String randomString() {
  return Random().nextInt(99999999).toString();
}

class EaseCallModel {
  bool hasJoinedChannel = false;
  final String curDevId = randomString();

  ECCall? curCall;
  Map<String, ECCall> recvCalls = {};
  String? curEid;
  String? agoraRtcToken;
  int? agoraUid;
  EaseCallState _state = EaseCallState.idle;

  void Function(EaseCallState to, EaseCallState from)? stateChangeHandle;

  set state(EaseCallState state) {
    if (_state == state) return;
    _state = state;
    stateChangeHandle?.call(state, _state);
  }

  EaseCallState get state => _state;

  EaseCallModel({
    this.curCall,
    this.curEid,
    this.agoraRtcToken,
    this.agoraUid,
    this.stateChangeHandle,
  });

  EaseCallModel copyWith({
    ECCall? curCall,
    Map<String, ECCall>? recvCalls,
    String? curEid,
    String? agoraRtcToken,
    int? agoraUid,
  }) {
    return EaseCallModel(
      curCall: curCall ?? this.curCall,
      curEid: curEid ?? this.curEid,
      agoraRtcToken: agoraRtcToken ?? this.agoraRtcToken,
      agoraUid: agoraUid ?? this.agoraUid,
    )
      ..state = _state
      ..stateChangeHandle = stateChangeHandle;
  }
}

class CallMessage implements EMMessageStatusListener {
  final EMMessage msg;
  Completer<EMError?>? hasSend;
  CallMessage(
    this.msg,
  );

  Future<void> send({bool isAsync = false}) async {
    msg.setMessageListener(this);
    EMClient.getInstance.chatManager.sendMessage(msg);
    if (isAsync) {
      return;
    }
    hasSend = Completer();
    EMError? error = await hasSend?.future;
    if (error != null) {
      throw (EaseCallError(
        error.code,
        EaseCallErrorType.im,
        error.description,
      ));
    }
  }

  @override
  void onDeliveryAck() {}

  @override
  void onError(EMError error) {
    hasSend?.complete(error);
  }

  @override
  void onProgress(int progress) {}

  @override
  void onReadAck() {}

  @override
  void onStatusChanged() {}

  @override
  void onSuccess() {
    hasSend?.complete(null);
  }
}
