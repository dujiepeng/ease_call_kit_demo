import 'dart:async';
import 'dart:math';

import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_eccall.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_error.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';

import 'package:im_flutter_sdk/im_flutter_sdk.dart';

String randomString() {
  return Random().nextInt(99999999).toString();
}

class EaseCallModel {
  bool hasJoinedChannel = false;
  final String currDevId = randomString();

  ECCall? currCall;
  Map<String, ECCall> recvCalls = {};
  String? currEid;
  String? agoraRtcToken;
  int? agoraUid;
  bool isMin;
  bool isMute;
  bool isSpeaker;
  int time = 0;
  EaseCallState _state = EaseCallState.idle;

  void Function(EaseCallState to, EaseCallState from)? stateChangeHandle;

  set state(EaseCallState state) {
    _state = state;
    stateChangeHandle?.call(state, _state);
  }

  EaseCallState get state => _state;

  EaseCallModel({
    this.currCall,
    this.currEid,
    this.agoraRtcToken,
    this.agoraUid,
    this.isMin = false,
    this.isSpeaker = false,
    this.isMute = false,
    this.stateChangeHandle,
  });

  EaseCallModel copyWith({
    ECCall? currCall,
    Map<String, ECCall>? recvCalls,
    String? currEid,
    String? agoraRtcToken,
    int? agoraUid,
    bool? isMin,
    bool? isSpeaker,
    bool? isMute,
  }) {
    return EaseCallModel(
      currCall: currCall ?? this.currCall,
      currEid: currEid ?? this.currEid,
      agoraRtcToken: agoraRtcToken ?? this.agoraRtcToken,
      agoraUid: agoraUid ?? this.agoraUid,
      isMin: isMin ?? this.isMin,
      isMute: isMute ?? this.isMute,
      isSpeaker: isSpeaker ?? this.isSpeaker,
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
