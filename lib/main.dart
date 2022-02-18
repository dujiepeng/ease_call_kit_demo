import 'dart:convert';
import 'dart:io';
import 'dart:convert' as convert;

import 'package:ease_call_kit_demo/ease_call_kit/ease_call_manager.dart';
import 'package:ease_call_kit_demo/ease_call_kit/ease_call_page.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_error.dart';
import 'package:flutter/material.dart';
import 'package:im_flutter_sdk/im_flutter_sdk.dart';

import 'ease_call_kit/models/ease_call_event_handle.dart';

String defineAppKey = "1110200629107815#flutter";
String defineAgoraId = "15cb0d28b87b425ea613fc46f7c9f974";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() async {
    try {
      await EaseCallManager.instance.startSingleCall("du002");
    } on EaseCallError catch (e) {
      debugPrint("code: ${e.errCode}, desc: ${e.errDesc}");
    }
  }

  @override
  void initState() {
    _initSDK();
    EaseCallManager.instance.setHandle(
      EaseCallEventHandle(
        startTalking: (channelName, remoteEid) => {
          debugPrint("---通话接通: $channelName, $remoteEid"),
        },
        callDidRequestTokenForAppId: (appId, channelName, eid, agoraUId) {
          debugPrint("---收到需要获取token回调");
          fetchRTCToken(channelName, EMClient.getInstance.currentUsername!);
        },
        callDidEnd: (channel, reason, time, type, remoteEid) {
          debugPrint("---通话结束: $channel, $reason, $time, $type, $remoteEid");
        },
        callDidOccurError: (remoteId, error) => {
          debugPrint("---通话报错 $remoteId, $error"),
        },
        callDidReceive: (type, inviter, ext) => {
          debugPrint("---收到呼叫 $type, $inviter, $ext"),
        },
        multiCallDidInviting: (users) => {
          debugPrint("---收到多人通话邀请 $users"),
        },
        remoteUserDidJoinChannel: (channelName, agoraUId, eid) => {
          debugPrint("---有人加入会议 $channelName, $agoraUId, $eid"),
        },
        didJoinChannel: (channelName, agoraUid) => {
          debugPrint("---自己加入channel: $channelName, $agoraUid"),
        },
      ),
    );
    super.initState();
  }

  void _initSDK() async {
    var options = EMOptions(appKey: defineAppKey);
    options.debugModel = true;
    options.autoLogin = false;

    await EMClient.getInstance.init(options);
    await EMClient.getInstance.login("du001", "1");
    if (!EMClient.getInstance.isLoginBefore!) {
      try {
        await EMClient.getInstance.login("du001", "1");
      } on EMError {
        debugPrint("login error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: EaseCallPage(
          appId: defineAgoraId,
          child: const Center(
            child: Text("Text"),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> fetchRTCToken(String channelName, String username) async {
    String? token = EMClient.getInstance.accessToken;
    if (token == null) return null;
    var httpClient = HttpClient();
    var uri = Uri.http("a1.easemob.com", "/token/rtcToken/v1", {
      "userAccount": username,
      "channelName": channelName,
      "appkey": defineAppKey,
    });
    var request = await httpClient.getUrl(uri);
    request.headers.add("Authorization", "Bearer $token");
    HttpClientResponse response = await request.close();
    httpClient.close();
    if (response.statusCode == HttpStatus.ok) {
      var _content = await response.transform(const Utf8Decoder()).join();
      debugPrint(_content);
      Map<String, dynamic>? map = convert.jsonDecode(_content);
      if (map != null) {
        if (map["code"] == "RES_0K") {
          debugPrint("获取数据成功: $map");
          String rtcToken = map["accessToken"];
          int agoraUserId = map["agoraUserId"];

          EaseCallManager.instance.setRtcToken(
            rtcToken,
            channelName,
            agoraUserId,
          );
        }
      }
    }
  }
}
