import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';

class ECCall {
  String? callId;
  String? remoteEid;
  String? remoteDevId;
  EaseCallType? callType;
  late bool isCaller;
  int? uid;
  late Map<int, String> users;
  String? channelName;
  String? ext;

  ECCall({
    this.callId,
    this.remoteEid,
    this.remoteDevId,
    this.callType,
    this.isCaller = false,
    this.uid,
    Map<int, String>? users,
    this.channelName,
    this.ext,
  }) {
    this.users = users ?? <int, String>{};
  }

  ECCall copyWith({
    String? callId,
    String? remoteEid,
    String? remoteDevId,
    EaseCallType? callType,
    bool? isCaller,
    int? uid,
    Map<int, String>? users,
    String? channelName,
    String? ext,
  }) {
    return ECCall(
      callId: callId ?? this.callId,
      remoteEid: remoteEid ?? this.remoteEid,
      remoteDevId: remoteDevId ?? this.remoteDevId,
      callType: callType ?? this.callType,
      isCaller: isCaller ?? this.isCaller,
      uid: uid ?? this.uid,
      users: users ?? this.users,
      channelName: channelName ?? this.channelName,
      ext: ext ?? this.ext,
    );
  }
}
