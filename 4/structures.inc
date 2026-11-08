struct MAPPLICATION
    hMemHeap          rd 1
    hAccelTable       rd 1
    hModule           rd 1
    uOldWheelMsgID    rd 1
    hSystemFont       rd 1
    lpCurrentImage    rd 1
ends

struct MWINDOW
    hWindow           rd 1
    width             rw 1
    height            rw 1
    hbrBg             rd 1
    hBBufMemDC        rd 1
    hBBufBitmap       rd 1
    hBBufOldBmp       rd 1
ends

struct MKEYBOARD             ; 0         8         16        24        32        40
    bKeys             rb 8   ; [01234567][89ABCDEF][GHIJKLMN][OPQRSTUV][WXYZ    ]
ends

struct MMOUSE
    wheelAccum        rd 1
ends

struct SHFILEINFO
    hIcon             dd ?
    iIcon             dd ?
    dwAttributes      dd ?
    szDisplayName     rw 260
    szTypeName        rw 80
ends

struct TVITEM
    mask              dd ?
    hItem             dd ?
    state             dd ?
    stateMask         dd ?
    pszText           dd ?
    cchTextMax        dd ?
    iImage            dd ?
    iSelectedImage    dd ?
    cChildren         dd ?
    lParam            dd ?
ends

struct TVINSERTSTRUCT
    hParent           dd ?
    hInsertAfter      dd ?
    item              TVITEM
ends

struct LVCOLUMN
    mask              dd ?
    fmt               dd ?
    cx                dd ?
    pszText           dd ?
    cchTextMax        dd ?
    iSubItem          dd ?
    iImage            dd ?
    iOrder            dd ?
ends

struct LVITEM
    mask              dd ?
    iItem             dd ?
    iSubItem          dd ?
    state             dd ?
    stateMask         dd ?
    pszText           dd ?
    cchTextMax        dd ?
    iImage            dd ?
    lParam            dd ?
    iIndent           dd ?
ends

struct EDITVALUERESULT
    dwType            dd ?
    bSuccess          dd ?
    szName            rw 260
    szData            rw 1024
ends

struct ICONINFO
    fIcon             dd ?
    xHotspot          dd ?
    yHotspot          dd ?
    hbmMask           dd ?
    hbmColor          dd ?
ends
