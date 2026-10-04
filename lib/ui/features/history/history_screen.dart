import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_notice.dart';
import '../../core/widgets/app_snack_bar.dart';

/// 작성: 2026-10-04 18:38:14 · nada
/// 클래스: _Status
/// 목적: 목록 한 줄에 붙이는 측정 상태. 색 · 아이콘 · 글자를 함께 써서
///       색을 구분하기 어려워도 알아볼 수 있게 한다.
///       - `exceeded` — 하나라도 적색 기준을 넘었다
///       - `normal` — 판정할 수 있는 지표가 모두 기준 안이다
///       - `unmeasured` — 판정할 수 있는 지표가 하나도 없다
enum _Status { exceeded, normal, unmeasured }

/// 작성: 2026-07-03 15:21:58 · 박건준
/// 수정: 2026-10-04 18:38:14 · nada
/// 클래스: HistoryScreen
/// 목적: 기기에 저장된 측정 결과 목록 화면. 최근 것부터 보여주고, 한 줄을
///       누르면 그 측정의 결과 화면(`ResultScreen`)을 연다. 줄마다 삭제할
///       수 있다. 목록은 측정마다 저장된 요약 파일에서 읽으므로 시계열은
///       비어 있다 — 이 화면이 쓰는 날짜와 판정은 요약에 다 들어 있다.
class HistoryScreen extends StatefulWidget {
  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: HistoryScreen
  /// 목적: 인자 없이 화면을 만든다.
  const HistoryScreen({super.key});

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: createState
  /// 목적: 이 화면의 상태 객체(`_HistoryScreenState`)를 만든다.
  /// 반환: 새로 만든 상태 객체
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// 작성: 2026-07-03 15:21:58 · 박건준
/// 수정: 2026-10-04 18:38:14 · nada
/// 클래스: _HistoryScreenState
/// 목적: 저장된 측정 결과 목록을 읽어 오고, 결과 화면으로 넘기고, 한 건씩
///       지우는 상태를 관리한다.
class _HistoryScreenState extends State<HistoryScreen> {
  /// 화면에 보여줄 측정 결과 목록. `_loadItems()` 가 채운다. 최근 것부터
  List<MeasurementResult> _items = <MeasurementResult>[];

  /// 목록을 읽는 중인지. 처음에는 true, `_loadItems()` 가 끝나면 false
  bool _loading = true;

  /// 목록 읽기가 실패했는지. true 면 실패 안내와 다시 시도 버튼을 보여준다
  bool _loadFailed = false;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: initState
  /// 목적: 이 화면이 나타날 때 한 번, 저장된 결과 목록을 불러온다.
  @override
  void initState() {
    super.initState();
    _loadItems(); // → 로직 이동: _loadItems()
  }

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _loadItems
  /// 목적: 저장소에서 측정 결과 목록을 불러와 화면 상태에 채운다.
  ///       조회에 실패하면 빈 목록으로 두고 실패 상태를 표시한다.
  Future<void> _loadItems() async {
    List<MeasurementResult> list = <MeasurementResult>[]; // 읽은 목록
    var failed = false; // 읽기가 실패했는지
    try {
      // → 로직 이동: MeasurementRepository.list()
      list = await MeasurementRepository.instance.list();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loadFailed = failed;
      _loading = false;
    });
  }

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: _open
  /// 목적: 고른 측정의 결과 화면을 연다. 결과 화면에서 테스트를 다시
  ///       재면 새 결과가 생기므로, 돌아오면 목록을 새로 읽는다.
  /// 인자: item — 열 측정 결과
  Future<void> _open(MeasurementResult item) async {
    await context.push('/result/${item.id}'); // → 로직 이동: ResultScreen.build()
    if (mounted) _loadItems(); // → 로직 이동: _loadItems()
  }

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _confirmDelete
  /// 목적: 측정 결과 한 건을 지운다. 되돌릴 수 없어 먼저 확인을 받는다.
  ///       이미 지워진 기록이면 그렇다고 알리고 목록을 새로 읽는다.
  /// 인자: item — 지울 측정 결과
  Future<void> _confirmDelete(MeasurementResult item) async {
    // → 로직 이동: showAppConfirmDialog()
    final confirmed = await showAppConfirmDialog(
      context,
      title: '측정 결과 삭제',
      message:
          '${item.jobNo} (${_formatDate(item.dateTime)}) 결과를 삭제할까요?\n'
          '이 작업은 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      cancelLabel: '취소',
      isDestructive: true,
      barrierDismissible: true,
    ); // 삭제를 골랐는지
    if (!confirmed) return;

    bool removed; // 실제로 지웠으면 true
    try {
      // → 로직 이동: MeasurementRepository.delete()
      removed = await MeasurementRepository.instance.delete(item.id);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '측정 기록을 삭제하지 못했습니다.');
      return;
    }
    if (!mounted) return;
    if (!removed) {
      showErrorSnackBar(context, '이미 지워진 기록입니다. 목록을 새로 고칩니다.');
      await _loadItems(); // → 로직 이동: _loadItems()
      return;
    }
    setState(() => _items.removeWhere((i) => i.id == item.id));
    showSuccessSnackBar(context, '측정 결과가 삭제되었습니다');
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _formatDate
  /// 목적: 측정 일시를 목록에 쓸 문구로 바꾼다.
  /// 인자: dt — 측정 일시
  /// 반환: "yyyy-MM-dd HH:mm" 꼴 문구
  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: _statusOf
  /// 목적: 측정 결과의 상태를 정한다. 판정은 세 축 진동과 소음 최대를 본다.
  /// 인자: item — 판정할 측정 결과
  /// 반환: 하나라도 넘었으면 `exceeded`, 판정할 지표가 하나도 없으면
  ///       `unmeasured`, 그 밖에는 `normal`
  _Status _statusOf(MeasurementResult item) {
    final judged = <bool?>[
      item.xExceeded,
      item.yExceeded,
      item.zExceeded,
      item.noiseExceeded,
    ]; // 세 축과 소음의 판정 결과. 아직 재지 않은 항목은 null
    if (judged.contains(true)) return _Status.exceeded;
    if (judged.every((v) => v == null)) return _Status.unmeasured;
    return _Status.normal;
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _getSummaryText
  /// 목적: 목록 한 줄에 보여줄 요약 문구를 만든다. 초과한 항목이 있으면
  ///       그 항목만 나열하고, 초과가 없으면 "전 지표 정상"을 쓴다.
  ///       - 판정할 수 있는 지표가 하나도 없으면 "정상" 대신 미측정임을
  ///         그대로 밝힌다. 아직 재지 않은 것을 통과로 읽히게 두면 안 된다
  ///       - 일부만 쟀으면 몇 개가 미측정인지 함께 적는다
  /// 인자: item — 요약할 측정 결과
  /// 반환: 요약 문구
  String _getSummaryText(MeasurementResult item) {
    final judged = <bool?>[
      item.xExceeded,
      item.yExceeded,
      item.zExceeded,
      item.noiseExceeded,
    ]; // 세 축과 소음의 판정 결과. 아직 재지 않은 항목은 null
    final unmeasured = judged.where((v) => v == null).length; // 미측정 항목 수
    if (unmeasured == judged.length) return '미측정 (진동 · 소음 지표 없음)';

    final reasons = <String>[
      if (item.xExceeded == true) 'X ${item.xPtp!.toStringAsFixed(1)}mg',
      if (item.yExceeded == true) 'Y ${item.yPtp!.toStringAsFixed(1)}mg',
      if (item.zExceeded == true) 'Z ${item.zPtp!.toStringAsFixed(1)}mg',
      if (item.noiseExceeded == true)
        '소음 ${item.noiseMax!.toStringAsFixed(1)}dBA',
    ]; // 초과한 항목 문구
    if (reasons.isEmpty) {
      return unmeasured == 0 ? '전 지표 정상' : '잰 지표는 정상 (미측정 $unmeasured개)';
    }
    return '${reasons.join(', ')} 초과';
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _buildEmptyState
  /// 목적: 목록이 비었거나 읽지 못했을 때의 안내를 만든다. 읽지 못했으면
  ///       다시 시도 버튼을, 비었으면 홈으로 돌아가 측정하러 가는 버튼을
  ///       둔다.
  /// 반환: 빈 상태 안내 위젯
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadFailed)
              const AppNotice(
                icon: Icons.error_outline,
                message: '저장된 결과를 불러오지 못했습니다.\n잠시 뒤 다시 시도해 주세요.',
                tone: NoticeTone.danger,
              )
            else
              Text(
                '저장된 결과가 없습니다',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textSub),
              ),
            const SizedBox(height: AppDims.gap3),
            if (_loadFailed)
              OutlinedButton(
                onPressed: _loadItems, // → 로직 이동: _loadItems()
                child: const Text('다시 시도'),
              )
            else
              OutlinedButton(
                // 홈(현장 정보 입력)으로 돌아간다
                onPressed: () => context.pop(),
                child: const Text('측정하러 가기'),
              ),
          ],
        ),
      ),
    );
  }

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: _buildStatusBadge
  /// 목적: 상태를 아이콘 + 글자로 보여주는 표시를 만든다.
  /// 인자: status — 보여줄 상태
  /// 반환: 상태 표시 위젯
  Widget _buildStatusBadge(_Status status) {
    final (color, icon, label) = switch (status) {
      _Status.exceeded => (AppColors.red, Icons.error, '초과'),
      _Status.normal => (AppColors.green, Icons.check_circle, '정상'),
      _Status.unmeasured => (AppColors.textSub, Icons.remove_circle, '미측정'),
    }; // 상태별 색 · 아이콘 · 글자
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppDims.iconS),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: _buildListItem
  /// 목적: 측정 결과 한 줄을 만든다. 왼쪽부터 상태, 제번 · 현장명과
  ///       측정 일시 · 요약, 삭제 버튼, 넘어가기 표시를 둔다. 줄 어디를
  ///       눌러도 결과 화면이 열린다.
  /// 인자: item — 보여줄 측정 결과
  /// 반환: 목록 한 줄 위젯
  Widget _buildListItem(MeasurementResult item) {
    return InkWell(
      // → 로직 이동: _open()
      onTap: () => _open(item),
      borderRadius: BorderRadius.circular(AppDims.radius),
      child: AppCard(
        minHeight: AppDims.choiceCardH,
        padding: const EdgeInsets.only(
          left: AppDims.gap2,
          top: AppDims.gap,
          bottom: AppDims.gap,
        ),
        child: Row(
          children: [
            _buildStatusBadge(_statusOf(item)), // → 로직 이동: _statusOf()
            const SizedBox(width: AppDims.gap2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.jobNo} · ${item.siteName}',
                    style: AppText.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDims.gapHalf),
                  Text(
                    // → 로직 이동: _getSummaryText()
                    '${_formatDate(item.dateTime)} · ${_getSummaryText(item)}',
                    style: AppText.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppDialogIconButton(
              icon: Icons.delete_outline,
              label: '측정 결과 삭제',
              color: AppColors.red,
              onPressed: () =>
                  _confirmDelete(item), // → 로직 이동: _confirmDelete()
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSub,
              size: AppDims.iconS,
            ),
          ],
        ),
      ),
    );
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 18:38:14 · nada
  /// 함수: build
  /// 목적: 목록 화면을 그린다. 읽는 중이면 진행 표시, 비었거나 읽지
  ///       못했으면 안내, 그 밖에는 저장 결과를 한 줄씩 늘어놓는다. 넓은
  ///       화면에서는 다른 화면과 같은 최대 폭으로 가운데 둔다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저장된 결과')),
      body: SafeArea(
        // 시스템 영역을 피해서 배치
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? _buildEmptyState() // → 로직 이동: _buildEmptyState()
            : Center(
                child: ConstrainedBox(
                  // 넓은 화면에서 폭이 과하게 늘어나지 않게 제한
                  constraints: const BoxConstraints(
                    maxWidth: AppDims.contentMaxWidth,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDims.screenPad),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDims.gap),
                    // → 로직 이동: _buildListItem()
                    itemBuilder: (_, index) => _buildListItem(_items[index]),
                  ),
                ),
              ),
      ),
    );
  }
}
