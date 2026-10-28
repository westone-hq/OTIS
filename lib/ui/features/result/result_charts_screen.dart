import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/domain/measurement/measurement_naming.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_layout.dart';
import 'package:vibration_checker/ui/core/widgets/app_notice.dart';
import 'package:vibration_checker/ui/features/result/result_charts.dart';

/// 작성: 2026-10-27 14:00:00 · 박건준
/// 클래스: ResultChartsScreen
/// 목적: 측정 결과 한 건의 그래프만 보는 화면(`/result/:id/charts`). 결과
///       화면의 "그래프 보기" 버튼이 연다. 결과 화면 아래에 그래프를 두면
///       지표 · 결과 비교를 보려 할 때 스크롤이 길어져, 따로 연다.
/// 근거: 인용 — 2026-10-27 사용자 지시 "그래프 보기 버튼 만들어서 따로 섹션
///       볼 수 있도록. 결과 비교 같은건 어렵기 때문에"
class ResultChartsScreen extends StatefulWidget {
  /// 그래프를 볼 측정 결과의 식별자
  final String id;

  /// 작성: 2026-10-27 14:00:00 · 박건준
  /// 함수: ResultChartsScreen
  /// 목적: 그래프를 볼 측정 결과의 식별자를 받는다.
  /// 인자: id — 측정 결과 식별자
  const ResultChartsScreen({super.key, required this.id});

  @override
  State<ResultChartsScreen> createState() => _ResultChartsScreenState();
}

/// 작성: 2026-10-27 14:00:00 · 박건준
/// 클래스: _ResultChartsScreenState
/// 목적: 그래프 화면의 상태. 측정 결과를 읽어 그래프 묶음(`ResultCharts`)에
///       넘긴다.
class _ResultChartsScreenState extends State<ResultChartsScreen> {
  /// 그릴 측정 결과. `_load()` 가 채운다. 읽기 전이거나 못 찾았으면 null
  MeasurementResult? _result;

  /// 결과를 읽는 중인지. 처음에는 true, `_load()` 가 끝나면 false
  bool _loading = true;

  /// 작성: 2026-10-27 14:00:00 · 박건준
  /// 함수: initState
  /// 목적: 화면이 처음 만들어질 때 측정 결과를 읽기 시작한다.
  @override
  void initState() {
    super.initState();
    _load(); // → 로직 이동: _load()
  }

  /// 작성: 2026-10-27 14:00:00 · 박건준
  /// 함수: _load
  /// 목적: `id` 의 측정 결과를 저장소에서 읽는다. 읽지 못하면 결과 없이
  ///       읽기를 끝내 "찾을 수 없음" 안내가 나오게 한다(결과 화면과 같다).
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

  /// 작성: 2026-10-27 14:00:00 · 박건준
  /// 함수: build
  /// 목적: 그래프 화면을 그린다. 읽는 중이면 진행 표시, 못 찾았으면 안내
  ///       박스, 그 밖에는 어느 측정인지(`MeasurementNaming.title()`) 한 줄과
  ///       그래프 네 장을 쌓는다.
  /// 인자: context — 이 화면이 어디에 놓이는지 알려주는 값
  /// 반환: 그래프 화면 전체를 담는 `Scaffold` 위젯
  @override
  Widget build(BuildContext context) {
    final result = _result; // 그릴 측정 결과, 없으면 null
    return Scaffold(
      appBar: AppBar(title: const Text('측정 그래프')),
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
                Text(
                  // → 로직 이동: MeasurementNaming.title()
                  '${MeasurementNaming.title(result)} · ${result.siteName}',
                  style: AppText.bodyBold,
                ),
                const SizedBox(height: AppDims.gap2),
                // → 로직 이동: ResultCharts.build()
                ResultCharts(result: result),
              ],
            ),
    );
  }
}
