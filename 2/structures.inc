struc MAPPLICATION {
    .hMemHeap          rd 1
    .hAccelTable       rd 1
    .hModule           rd 1
    .uOldWheelMsgID    rd 1
}

struc MWINDOW {
    .hWindow           rd 1
    .width             rw 1
    .height            rw 1
    .hbrBg             rd 1
    .hBBufMemDC        rd 1
    .hBBufBitmap       rd 1
    .hBBufOldBmp       rd 1
}

struc MGRID {
    .width             rw 1
    .height            rw 1
    .wColsCount        rw 1
    .wRowsCount        rw 1
    .wColWidth         rw 1
    .wSelectedCol      rw 1
    .wSelectedRow      rw 1
    .lpStrs            rd 1
    .scrollY           rd 1
    .hFontNormal       rd 1
    .hFontBold         rd 1
    .hFontItalic       rd 1
    .hFontBoldItalic   rd 1
}

struc MKEYBOARD {            ; 0         8         16        24        32        40
    .bKeys             rb 5  ; [01234567][89ABCDEF][GHIJKLMN][OPQRSTUV][WXYZ    ]
}

struc MMOUSE {
    .wheelAccum        rd 1
}