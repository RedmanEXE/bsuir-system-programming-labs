; UINT MessageBox.Show(HWND hWnd, LPWSTR lpszText, LPWSTR lpszCaption, UINT uType);
proc MessageBox.Show stdcall uses ecx edx,\
     hWnd:DWORD, lpszText:DWORD, lpszCaption:DWORD, uType:DWORD
    invoke    MessageBox, [hWnd], [lpszText], [lpszCaption], [uType]
    ret
endp

; BOOL MessageBox.Confirm(HWND hWnd, LPWSTR lpszText, LPWSTR lpszCaption);
proc MessageBox.Confirm stdcall uses ecx edx,\
     hWnd:DWORD, lpszText:DWORD, lpszCaption:DWORD
    invoke    MessageBox, [hWnd], [lpszText], [lpszCaption], MB_YESNO or MB_ICONQUESTION
    cmp       eax, IDYES
    sete      al
    movzx     eax, al
.Done:
    ret
endp

; VOID MessageBox.Warning(HWND hWnd, LPWSTR lpszText, LPWSTR lpszCaption);
proc MessageBox.Warning stdcall uses ecx edx,\
     hWnd:DWORD, lpszText:DWORD, lpszCaption:DWORD
    invoke    MessageBox, [hWnd], [lpszText], [lpszCaption], MB_OK or MB_ICONWARNING
    ret
endp

; VOID MessageBox.Error(HWND hWnd, LPWSTR lpszText, LPWSTR lpszCaption);
proc MessageBox.Error stdcall uses ecx edx,\
     hWnd:DWORD, lpszText:DWORD, lpszCaption:DWORD
    invoke    MessageBox, [hWnd], [lpszText], [lpszCaption], MB_OK or MB_ICONERROR
    ret
endp