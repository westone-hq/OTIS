import 'package:flutter/material.dart';

import 'package:vibration_checker/adapter/sensor_channel.dart';

import '../../core/widgets/app_dialog.dart';

/// 작성: 2026-10-04 18:15:24 · nada
/// 함수: ensureMicPermission
/// 목적: 측정 화면으로 넘어가기 전에 마이크 권한을 받는다. 측정 중에는
///       휴대폰을 뒤집어 놓으므로 그때 권한 창이 뜨면 누를 수 없다. 한 번
///       허용하면 다음부터는 창 없이 바로 통과한다.
///       거절하면 소음 없이 진동만 잴지 묻는다.
/// 인자: context — 대화상자를 띄울 화면의 위치 정보
///       sensorManager — 안드로이드에 권한을 요청할 통로
/// 반환: 측정 화면으로 넘어가도 되면 true. 권한을 거절하고 진동만 재기도
///       마다하면 false
Future<bool> ensureMicPermission(
  BuildContext context,
  SensorChannelManager sensorManager,
) async {
  // → 로직 이동: SensorChannelManager.requestAudioPermission()
  final granted = await sensorManager.requestAudioPermission(); // 허용했는지
  if (granted || !context.mounted) return granted;
  // → 로직 이동: showAppConfirmDialog()
  return showAppConfirmDialog(
    context,
    title: '마이크 권한 없음',
    message:
        '마이크 권한이 없어 소음은 측정하지 않고 진동만 측정합니다.\n'
        '권한 창이 다시 뜨지 않으면 휴대폰 설정 > 앱 > OTIS 진동 측정 > '
        '권한에서 마이크를 허용해 주세요.',
    confirmLabel: '진동만 측정',
    cancelLabel: '취소',
  );
}
