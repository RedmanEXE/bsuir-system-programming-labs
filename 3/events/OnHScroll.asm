; Check if scroll message came from speed trackbar
    mov       eax, [lParam]
    cmp       eax, [hSpeedTrackbar]
      jne     .HScrollDone

    ; Read snapped position from trackbar
    stdcall   TrackBar.GetPos, [hSpeedTrackbar]
    mov       [dwTransformDelayMs], eax

    ; If not currently mouse-dragging, snap thumb to tick mark
    movzx     ecx, word [wParam]
    cmp       ecx, 5                   ; TB_THUMBTRACK
      je      .HScrollDone
    stdcall   TrackBar.SetPos, [hSpeedTrackbar], eax

.HScrollDone:
