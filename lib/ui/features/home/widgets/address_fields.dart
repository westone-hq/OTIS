import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/features/home/widgets/field_error.dart';

/// 작성: 2026-10-04 16:44:32 · nada
/// 수정: 2026-10-22 23:10:00 · nada
/// 클래스: AddressFields
/// 목적: 우편번호와 현장 주소를 받는다. 둘 다 필수이고 리포트 머리말
///       주소 칸에 "주소, 우편번호" 로 찍힌다. 우편번호는 주소 위 줄에
///       화면 반 폭으로 둔다 — 주소와 한 줄에 두면 360dp 폭 화면에서
///       라벨과 다섯 자리가 잘린다(2026-10-11 캡처). 숫자 키패드로
///       `SiteInfo.postalCodeLength` 자리까지만 받는다. 두 칸이 오류 상자
///       하나를 함께 쓴다.
class AddressFields extends StatelessWidget {
  /// 오류가 났을 때 스크롤로 이 영역을 찾는 위치 키
  final GlobalKey anchorKey;

  /// 우편번호 입력칸의 텍스트 컨트롤러
  final TextEditingController postalCodeController;

  /// 우편번호 입력칸의 포커스 노드
  final FocusNode postalCodeFocus;

  /// 주소 입력칸의 텍스트 컨트롤러
  final TextEditingController addressController;

  /// 주소 입력칸의 포커스 노드. 우편번호에서 "다음" 을 누르면 옮겨 온다
  final FocusNode addressFocus;

  /// 우편번호 · 주소 오류 문구. 둘 다 걸리면 두 줄이다. null 이면 오류 없음
  final String? error;

  /// 주소에서 "다음" 을 눌렀을 때 부를 함수(최하층으로 포커스를 옮긴다)
  final VoidCallback onAddressSubmitted;

  /// 두 칸 가운데 하나라도 값이 바뀌면 부를 함수(저장 · 오류 지우기)
  final VoidCallback onChanged;

  /// 작성: 2026-10-22 23:10:00 · nada
  /// 함수: AddressFields
  /// 목적: 두 입력칸에 필요한 값을 받는다.
  /// 인자: anchorKey, postalCodeController, postalCodeFocus,
  ///       addressController, addressFocus, error, onAddressSubmitted,
  ///       onChanged — 위 필드 설명을 따른다
  const AddressFields({
    super.key,
    required this.anchorKey,
    required this.postalCodeController,
    required this.postalCodeFocus,
    required this.addressController,
    required this.addressFocus,
    required this.error,
    required this.onAddressSubmitted,
    required this.onChanged,
  });

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 수정: 2026-10-22 23:10:00 · nada
  /// 함수: build
  /// 목적: 라벨 → 우편번호(반 폭) → 주소 → (오류 박스) 를 세로로 놓는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('주소', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: postalCodeController,
                    focusNode: postalCodeFocus,
                    style: AppText.body,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        SiteInfo.postalCodeLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: '우편번호',
                      enabledBorder: error != null ? fieldErrorBorder() : null,
                      focusedBorder: error != null ? fieldErrorBorder() : null,
                    ),
                    onSubmitted: (_) => addressFocus.requestFocus(),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: AppDims.gap2),
              const Spacer(), // 우편번호 칸을 화면 반 폭으로 둔다
            ],
          ),
          const SizedBox(height: AppDims.gap),
          SizedBox(
            height: AppDims.fieldH,
            child: TextField(
              controller: addressController,
              focusNode: addressFocus,
              style: AppText.body,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '도로명 주소',
                enabledBorder: error != null ? fieldErrorBorder() : null,
                focusedBorder: error != null ? fieldErrorBorder() : null,
              ),
              onSubmitted: (_) => onAddressSubmitted(),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (error != null) FieldErrorBox(error!),
        ],
      ),
    );
  }
}
