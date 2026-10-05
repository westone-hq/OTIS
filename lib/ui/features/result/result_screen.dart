import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/model/measurement_result.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/app_notice.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../measure/mic_permission.dart';
import '../shared/send_email_sheet.dart';

/// 작성: 2026-10-04 18:15:24 · nada
/// 클래스: _Metric
/// 목적: 결과 화면에 한 줄로 보여줄 지표 하나의 정의. 이름 · 단위 · 값을
///       꺼내는 방법 · 적색 기준 · 소수 자리를 묶는다.
class _Metric {
  /// 화면에 보여줄 지표 이름
  final String label;

  /// 단위 (mg, dBA, m, m/s)
  final String unit;

  /// 측정 결과에서 이 지표 값을 꺼내는 함수. 값이 없으면 null 을 돌려준다
  final double? Function(MeasurementResult) read;

  /// 적색 기준. 이 값을 넘으면 붉게 표시한다. 기준이 없으면 null
  final double? redLimit;

  /// 값을 보여줄 소수 자리 수
  final int decimals;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _Metric
  /// 목적: 지표 정의를 받는다.
  /// 인자: label, unit, read, redLimit, decimals — 위 필드 설명을 따른다
  const _Metric({
    required this.label,
    required this.unit,
    required this.read,
    required this.decimals,
    this.redLimit,
  });
}

/// 작성: 2026-10-04 18:15:24 · nada
/// 변수: _metrics
/// 목적: 결과 화면에 보여줄 지표와 그 차례. 적색 기준은 리포트와 같은
///       `ReportThresholds` 값을 쓴다 — 화면과 리포트의 판정이 갈라지지
///       않게 하려는 것이다.
final List<_Metric> _metrics = <_Metric>[
  _Metric(
    label: 'X축 진동 Peak to Peak',
    unit: 'mg',
    read: (r) => r.xPtp,
    redLimit: ReportThresholds.xPtpRedMg,
    decimals: 1,
  ),
  _Metric(
    label: 'Y축 진동 Peak to Peak',
    unit: 'mg',
    read: (r) => r.yPtp,
    redLimit: ReportThresholds.yPtpRedMg,
    decimals: 1,
  ),
  _Metric(
    label: 'Z축 진동 Peak to Peak',
    unit: 'mg',
    read: (r) => r.zPtp,
    redLimit: ReportThresholds.zPtpRedMg,
    decimals: 1,
  ),
  _Metric(
    label: '소음 최대',
    unit: 'dBA',
    read: (r) => r.noiseMax,
    redLimit: ReportThresholds.noiseMaxRedDba,
    decimals: 1,
  ),
  _Metric(label: '운행 거리', unit: 'm', read: (r) => r.distance, decimals: 1),
  _Metric(label: '최대 속도', unit: 'm/s', read: (r) => r.maxSpeed, decimals: 2),
];

/// 작성: 2026-07-03 15:21:58 · 박건준
/// 수정: 2026-10-04 18:15:24 · nada
/// 클래스: ResultScreen
/// 목적: 저장된 측정 결과 하나를 보여주는 화면. 측정을 마쳤을 때와 저장
///       결과 목록에서 하나를 골랐을 때 같은 화면을 쓴다.
///       - 진동 세 축 · 소음 최대 · 운행 거리 · 최대 속도를 보여주고,
///         기준을 넘은 값은 붉게 표시한다
///       - 다른 저장 결과를 골라 지표마다 나란히 비교한다
///       - 메일 보내기, 같은 현장 정보로 테스트 재실행
class ResultScreen extends StatefulWidget {
  /// 표시할 측정 결과의 식별자
  final String id;

  /// 센서 통로를 바꿔 끼울 때 넘기는 값. null 이면 테스트 재실행 때
  /// 마이크 권한을 묻는 데 실제 `SensorChannelManager` 를 새로 만든다
  final SensorChannelManager? sensorManager;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:15:24 · nada
  /// 함수: ResultScreen
  /// 목적: 보여줄 측정 결과의 식별자를 받아 화면을 만든다.
  /// 인자: id — 측정 결과 식별자
  ///       sensorManager — 바꿔 끼울 센서 통로. 보통은 넘기지 않는다
  const ResultScreen({super.key, required this.id, this.sensorManager});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

/// 작성: 2026-10-04 18:15:24 · nada
/// 클래스: _ResultScreenState
/// 목적: 결과 화면의 상태를 관리한다. 측정 결과를 읽어 오고, 비교 대상을
///       고르고, 메일 · 재실행으로 넘긴다.
class _ResultScreenState extends State<ResultScreen> {
  /// 테스트 재실행 때 마이크 권한을 묻는 통로
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();

  /// 화면에 보여줄 측정 결과. `_load()` 가 채운다. 읽기 전이거나 못
  /// 찾았으면 null
  MeasurementResult? _result;

  /// 결과를 읽는 중인지. 처음에는 true, `_load()` 가 끝나면 false
  bool _loading = true;

  /// 견줘 볼 다른 저장 결과. `_pickCompare()` 가 채우고, "비교 해제" 로
  /// 비운다. 비교하지 않으면 null
  MeasurementResult? _compare;

  /// 테스트 재실행을 진행 중인지. true 인 동안 버튼을 막아, 연타로 측정
  /// 화면이 두 번 열리거나 권한 요청이 겹치지 않게 한다
  bool _rerunning = false;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: initState
  /// 목적: 화면이 처음 만들어질 때 측정 결과를 읽기 시작한다.
  @override
  void initState() {
    super.initState();
    _load(); // → 로직 이동: _load()
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _load
  /// 목적: `id` 의 측정 결과를 저장소에서 읽는다. 읽지 못하면 결과 없이
  ///       읽기를 끝내 "찾을 수 없음" 안내가 나오게 한다.
  Future<void> _load() async {
    MeasurementResult? result; // 읽은 측정 결과, 못 읽었으면 null
    try {
      // → 로직 이동: MeasurementRepository.load()
      result = await MeasurementRepository.instance.load(widget.id);
    } catch (e) {
      debugPrint('측정 결과 읽기 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _pickCompare
  /// 목적: 이 결과 말고 저장된 결과 목록을 시트로 보여주고, 고른 하나를
  ///       비교 대상으로 둔다. 견줄 결과가 없으면 그렇다고 알린다.
  Future<void> _pickCompare() async {
    List<MeasurementResult> others; // 이 결과를 뺀 저장 결과, 최근 것부터
    try {
      // → 로직 이동: MeasurementRepository.list()
      final all = await MeasurementRepository.instance.list(); // 저장 결과 전부
      others = all.where((r) => r.id != widget.id).toList();
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '저장된 결과를 불러오지 못했습니다.');
      return;
    }
    if (!mounted) return;
    if (others.isEmpty) {
      showErrorSnackBar(context, '비교할 다른 저장 결과가 없습니다.');
      return;
    }

    MeasurementResult? picked; // 시트에서 고른 결과, 고르지 않았으면 null
    // → 로직 이동: showAppSheet()
    await showAppSheet(
      context,
      builder: (sheetContext) => _CompareSheet(
        candidates: others,
        onPicked: (result) {
          picked = result;
          Navigator.of(sheetContext).pop();
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _compare = picked);
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _rerun
  /// 목적: 이 결과와 같은 현장 정보로 곧바로 다시 측정한다. 순서대로
  ///       진행한다.
  ///       1. 운전 방향을 다시 고르게 한다. 상승 측정 다음은 보통 하강이라
  ///          그대로 두면 리포트의 방향이 틀린다
  ///       2. 시작 화면을 거치지 않으므로 여기서 마이크 권한을 받는다
  ///       3. 이 화면을 측정 화면으로 바꾼다. 재측정이 끝난 뒤 뒤로 가면
  ///          이 화면을 연 곳으로 돌아간다
  ///       어느 단계에서든 취소하면 이 화면에 머문다. 진행하는 동안에는
  ///       버튼을 막는다.
  Future<void> _rerun() async {
    final result = _result; // 다시 잴 측정 결과
    if (result == null || _rerunning) return;
    setState(() => _rerunning = true);
    try {
      // → 로직 이동: _askDirection()
      final direction = await _askDirection(result.direction); // 고른 방향
      if (direction == null || !mounted) return;
      // → 로직 이동: SiteInfo.fromResult()
      final site = SiteInfo.fromResult(result); // 지난 측정의 현장 정보
      MeasurementSession.instance.currentSite = SiteInfo(
        jobNo: site.jobNo,
        siteName: site.siteName,
        address: site.address,
        bottomFloor: site.bottomFloor,
        topFloor: site.topFloor,
        direction: direction,
        model: site.model,
      );
      // → 로직 이동: ensureMicPermission()
      final proceed = await ensureMicPermission(
        context,
        _sensorManager,
      ); // 측정 화면으로 넘어가도 되는지
      if (!proceed || !mounted) return;
      // → 로직 이동: MeasuringScreen.build()
      context.pushReplacement('/measuring');
    } finally {
      if (mounted) setState(() => _rerunning = false);
    }
  }

  /// 작성: 2026-10-05 10:03:35 · nada
  /// 함수: _askDirection
  /// 목적: 다시 잴 운전 방향을 고르게 한다. 지난 측정과 반대 방향을 주
  ///       버튼으로 두어 한 번에 고를 수 있게 한다. 바깥을 누르면 취소다.
  /// 인자: last — 지난 측정의 운전 방향
  /// 반환: 고른 방향(`SiteInfo.directionUp` 또는 `directionDown`).
  ///       취소했으면 null
  Future<String?> _askDirection(String last) {
    final suggested = last == SiteInfo.directionUp
        ? SiteInfo.directionDown
        : SiteInfo.directionUp; // 주 버튼으로 둘 방향
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('운전 방향 확인', style: AppText.subhead),
        content: Text(
          '이번 측정의 운전 방향을 고르세요.\n지난 측정은 $last 이었습니다.',
          style: AppText.body,
        ),
        actions: [
          for (final option in <String>[
            SiteInfo.directionUp,
            SiteInfo.directionDown,
          ])
            AppDialogButton(
              label: option,
              onPressed: () => Navigator.of(ctx).pop(option),
              primary: option == suggested,
            ),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _format
  /// 목적: 지표 값을 정한 소수 자리로 바꾼다.
  /// 인자: value — 지표 값. 없으면 null
  ///       decimals — 소수 자리 수
  /// 반환: 화면에 쓸 문구. 값이 없으면 "—"
  String _format(double? value, int decimals) =>
      value == null ? '—' : value.toStringAsFixed(decimals);

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _isRed
  /// 목적: 지표 값이 적색 기준을 넘었는지 본다.
  /// 인자: metric — 지표 정의
  ///       value — 지표 값. 없으면 null
  /// 반환: 넘었으면 true. 기준이 없거나 값이 없거나 안 넘었으면 false
  bool _isRed(_Metric metric, double? value) {
    final limit = metric.redLimit; // 적색 기준, 없으면 null
    if (limit == null) return false;
    // → 로직 이동: ReportThresholds.exceeds()
    return ReportThresholds.exceeds(value, limit) ?? false;
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _buildHeader
  /// 목적: 어느 측정인지 알려주는 머리 카드를 만든다. 제번 · 현장명,
  ///       측정 일시, 운전 방향 · 층 · 기종, 주소(있을 때만)를 보여준다.
  /// 인자: result — 보여줄 측정 결과
  /// 반환: 머리 카드 위젯
  Widget _buildHeader(MeasurementResult result) {
    final when = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(result.dateTime); // 측정 일시 문구
    final model = result.model; // 기종, 없으면 null
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.jobNo} · ${result.siteName}', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gapHalf),
          Text(when, style: AppText.caption),
          Text(
            '${result.direction} · ${result.bottomFloor}층 → '
            '${result.topFloor}층${model == null ? '' : ' · $model'}',
            style: AppText.caption,
          ),
          if (result.address.isNotEmpty)
            Text(result.address, style: AppText.caption),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _buildCompareBanner
  /// 목적: 지금 무엇과 비교하는지 알리고 비교를 끌 수 있는 줄을 만든다.
  /// 인자: compare — 비교 대상 결과
  /// 반환: 비교 대상 안내 위젯
  Widget _buildCompareBanner(MeasurementResult compare) {
    final when = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(compare.dateTime); // 비교 대상 측정 일시
    return AppCard(
      padding: const EdgeInsets.only(left: AppDims.gap2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '비교: ${compare.jobNo} · $when',
              style: AppText.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppDialogButton(
            label: '비교 해제',
            onPressed: () => setState(() => _compare = null),
            primary: false,
            textColor: AppColors.blue,
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _buildMetricRow
  /// 목적: 지표 한 줄을 만든다. 왼쪽에 이름 · 단위와 적색 기준, 오른쪽에
  ///       값을 둔다. 기준을 넘은 값은 붉은 글자와 경고 아이콘으로 표시해
  ///       색만이 아니라 모양으로도 알린다. 비교 중이면 값 아래에 비교
  ///       값과 차이(이번 − 비교)를 덧붙인다.
  /// 인자: metric — 지표 정의
  ///       result — 이번 측정 결과
  /// 반환: 지표 한 줄 위젯
  Widget _buildMetricRow(_Metric metric, MeasurementResult result) {
    final value = metric.read(result); // 이번 값
    final red = _isRed(metric, value); // 이번 값이 기준을 넘었는지
    final compare = _compare; // 비교 대상, 없으면 null
    final other = compare == null ? null : metric.read(compare); // 비교 값
    final limit = metric.redLimit; // 적색 기준, 없으면 null

    return AppCard(
      minHeight: AppDims.rowMinH,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric.label} [${metric.unit}]',
                  style: AppText.bodyBold,
                ),
                if (limit != null)
                  Text(
                    '${_format(limit, 0)}${metric.unit} 초과 시 적색',
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDims.gap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (red)
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.red,
                      size: AppDims.iconS,
                    ),
                  if (red) const SizedBox(width: AppDims.gapHalf),
                  Text(
                    _format(value, metric.decimals),
                    style: AppText.subhead.copyWith(
                      color: red ? AppColors.red : AppColors.text,
                    ),
                  ),
                ],
              ),
              if (compare != null) ...[
                Text(
                  '비교 ${_format(other, metric.decimals)}',
                  style: AppText.caption.copyWith(
                    color: _isRed(metric, other)
                        ? AppColors.red
                        : AppColors.textSub,
                  ),
                ),
                Text(
                  '차이 ${_signedDiff(value, other, metric.decimals)}',
                  style: AppText.caption,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _signedDiff
  /// 목적: 이번 값에서 비교 값을 뺀 차이를 부호를 붙여 쓴다.
  /// 인자: value — 이번 값. 없으면 null
  ///       other — 비교 값. 없으면 null
  ///       decimals — 소수 자리 수
  /// 반환: "+1.2" · "-0.5" 꼴 문구. 어느 한쪽이라도 없으면 "—"
  String _signedDiff(double? value, double? other, int decimals) {
    if (value == null || other == null) return '—';
    final diff = value - other; // 이번 − 비교
    final text = diff.abs().toStringAsFixed(decimals); // 부호 뺀 차이
    return diff < 0 ? '-$text' : '+$text';
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-05 10:03:35 · nada
  /// 함수: build
  /// 목적: 결과 화면을 그린다.
  ///       - 읽는 중이면 진행 표시, 못 찾았으면 안내 박스
  ///       - `body` — 머리 카드 → (비교 중이면 비교 대상 줄) → 지표 여섯 줄
  ///       - `bottomNavigationBar` — 결과 비교 · 메일 보내기, 그 아래
  ///         테스트 재실행(진행 중에는 막는다)
  /// 인자: context — 이 화면이 어디에 놓이는지 알려주는 값
  /// 반환: 결과 화면 전체를 담는 `Scaffold` 위젯
  @override
  Widget build(BuildContext context) {
    final result = _result; // 보여줄 측정 결과, 없으면 null
    final compare = _compare; // 비교 대상, 없으면 null
    return Scaffold(
      appBar: AppBar(title: const Text('측정 결과')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : result == null
          ? const AppScrollBody(
              children: [
                AppNotice(
                  icon: Icons.error_outline,
                  message: '측정 결과를 찾을 수 없습니다.',
                  tone: NoticeTone.danger,
                ),
              ],
            )
          : AppScrollBody(
              children: [
                _buildHeader(result), // → 로직 이동: _buildHeader()
                const SizedBox(height: AppDims.gap2),
                if (compare != null) ...[
                  // → 로직 이동: _buildCompareBanner()
                  _buildCompareBanner(compare),
                  const SizedBox(height: AppDims.gap2),
                ],
                for (final metric in _metrics) ...[
                  // → 로직 이동: _buildMetricRow()
                  _buildMetricRow(metric, result),
                  const SizedBox(height: AppDims.gap),
                ],
              ],
            ),
      bottomNavigationBar: result == null
          ? null
          : AppBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCompare, // → 로직 이동: _pickCompare()
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('결과 비교'),
                        ),
                      ),
                      const SizedBox(width: AppDims.gap),
                      Expanded(
                        child: OutlinedButton.icon(
                          // → 로직 이동: showSendEmailSheet()
                          onPressed: () =>
                              showSendEmailSheet(context, jobId: widget.id),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('메일 보내기'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDims.gap),
                  ElevatedButton.icon(
                    // → 로직 이동: _rerun()
                    onPressed: _rerunning ? null : _rerun,
                    icon: const Icon(Icons.replay),
                    label: const Text('테스트 재실행'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 작성: 2026-10-04 18:15:24 · nada
/// 클래스: _CompareSheet
/// 목적: 비교할 저장 결과를 고르는 시트. 최근 것부터 한 줄씩 보여주고,
///       누르면 그 결과를 고른 것으로 알린다.
class _CompareSheet extends StatelessWidget {
  /// 고를 수 있는 저장 결과. 최근 것부터
  final List<MeasurementResult> candidates;

  /// 하나를 골랐을 때 부를 함수. 고른 결과를 받는다
  final void Function(MeasurementResult) onPicked;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _CompareSheet
  /// 목적: 고를 결과 목록과 골랐을 때 할 일을 받는다.
  /// 인자: candidates, onPicked — 위 필드 설명을 따른다
  const _CompareSheet({required this.candidates, required this.onPicked});

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: build
  /// 목적: 제목 아래에 저장 결과를 한 줄씩 늘어놓는다. 줄마다 제번 ·
  ///       현장명과 측정 일시를 보여준다.
  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.of(context).size.height * AppDims.sheetHeightFactor; // 시트 높이
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('비교할 결과 선택', style: AppText.subhead),
            const SizedBox(height: AppDims.gap2),
            Expanded(
              child: ListView.separated(
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppDims.gap),
                itemBuilder: (_, index) {
                  final item = candidates[index]; // 이 줄의 저장 결과
                  final when = DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(item.dateTime); // 측정 일시
                  return InkWell(
                    onTap: () => onPicked(item),
                    borderRadius: BorderRadius.circular(AppDims.radius),
                    child: AppCard(
                      minHeight: AppDims.rowMinH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.jobNo} · ${item.siteName}',
                            style: AppText.bodyBold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(when, style: AppText.caption),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
