import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_call/const/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  RtcEngine? engine;

  //my ID
  int? uid = 0;

  //other ID  value = null
  int? otherUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LIVE',
        ),
      ),
      body: FutureBuilder<Object>(
          future: init(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: renderMainView(),
                ),
                Stack(
                  children: [
                    renderMainView(),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        color: Colors.grey,
                        height: 160,
                        width: 120,
                        child: renderSubView(),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11.0,
                  ),
                  child: ElevatedButton(
                      onPressed: () async {
                        if (engine != null) {
                          await engine!.leaveChannel();
                          engine = null;
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text('채널나가기')),
                )
              ],
            );
          }),
    );
  }

  renderMainView() {
    if (uid == null) {
      return Center(
        child: Text('채널에 참여해주세요'),
      );
    } else {
      //채널에 참여하고 있을때
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine!,
          canvas: VideoCanvas(
            uid: 0,
          ),
        ),
      );
    }
  }

  renderSubView() {
    if(otherUid == null){
      return Center(
        child: Text('채널에 유저가 없습니다'),
      );
    }else{
      return AgoraVideoView(
        controller: VideoViewController.remote(
            rtcEngine: engine!,
            canvas: VideoCanvas(uid: otherUid),
            connection: RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    }
  }

  Future<bool> init() async {
    final resp = await [Permission.camera, Permission.microphone].request();

    final cameraPermission = resp[Permission.camera];
    final microphonePermission = resp[Permission.microphone];

    if (cameraPermission != PermissionStatus.granted ||
        microphonePermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다.';
    }

    if (engine == null) {
      engine = createAgoraRtcEngine(); //엔진 생성
      await engine!.initialize(
        RtcEngineContext(
          appId: APP_ID, //agora에서 가져온 아이디 앱아이디 기한으로 초기화
        ),
      );
      engine!.registerEventHandler(
        RtcEngineEventHandler(
          //내가 채널에 입장했을때
          //connection -> 연결정보
          //elapsed -> 연결된 시간(연결된지 얼마나 됐는지)
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              uid = connection.localUid;
            });
          },
          //내가 채널에서 나갔을때
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            setState(() {
              uid == null;
            });
          },
          //상대방 유저가 들어왔을때
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              otherUid == remoteUid;
            });
          },
          //상대가 나갔을때
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reasonType) {
            setState(() {
              otherUid == null;
            });
          },
        ),
      );
      await engine!.enableVideo();

      await engine!.startPreview();

      ChannelMediaOptions options = ChannelMediaOptions();
      await engine!.joinChannel(
        token: TEMP_TOKEN,
        channelId: CHANNEL_NAME,
        uid: 0,
        options: options,
      );
    }
    return true;
  }
}
