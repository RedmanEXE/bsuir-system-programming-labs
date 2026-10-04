struc MAPPLICATION {
    .hMemHeap          rd 1
    .hAccelTable       rd 1
    .hModule           rd 1
    .uOldWheelMsgID    rd 1
    .hSystemFont       rd 1
    .lpCurrentImage    rd 1
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

struc MKEYBOARD {            ; 0         8         16        24        32        40
    .bKeys             rb 5  ; [01234567][89ABCDEF][GHIJKLMN][OPQRSTUV][WXYZ    ]
}

struc MMOUSE {
    .wheelAccum        rd 1
}

sizeof.MWAITHANDLES2 = 8
struc MWAITHANDLES2 {
    .h0                rd 1
    .h1                rd 1
}

sizeof.MWAITHANDLES3 = 12
struc MWAITHANDLES3 {
    .h0                rd 1
    .h1                rd 1
    .h2                rd 1
}

sizeof.MCONCURRENTRINGBUFFER = 52
struc MCONCURRENTRINGBUFFER {
    .lpBuffer          rd 1
    .dwItemSize        rd 1
    .dwCapacity        rd 1
    .dwCount           rd 1
    .dwHead            rd 1
    .dwTail            rd 1
    .hSemaphoreItems   rd 1
    .hSemaphoreSlots   rd 1
    .critSection       rd 6
}

sizeof.MTHREADPOOLTASK = 8
struc MTHREADPOOLTASK {
    .pfnRoutine        rd 1
    .lpContext         rd 1
}

sizeof.MTHREADPOOL = 80
struc MTHREADPOOL {
    .hThreads          rd 16
    .dwThreadCount     rd 1
    .lpTaskQueue       rd 1
    .hStopEvent        rd 1
    .bRunning          rd 1
}

sizeof.MLOADTASK = 524
struc MLOADTASK {
    .dwTaskId          rd 1
    .szFilePath        rw 260
}

sizeof.MIMAGE = 36
struc MIMAGE {
    .hBitmap           rd 1
    .lpBits            rd 1
    .dwWidth           rd 1
    .dwHeight          rd 1
    .dwPitch           rd 1
    .dwBpp             rd 1
    .dwChunksTotal     rd 1
    .dwChunksRemaining rd 1
    .hEventComplete    rd 1
}

sizeof.MCHUNKTRANSFORMTASK = 16
struc MCHUNKTRANSFORMTASK {
    .lpImage           rd 1
    .dwChunkIndex      rd 1
    .dwStartY          rd 1
    .dwEndY            rd 1
}

sizeof.MSAVETASK = 524
struc MSAVETASK {
    .lpImage           rd 1
    .szFilePath        rw 260
}

sizeof.MTASKDISPATCHER = 28
struc MTASKDISPATCHER {
    .hThread           rd 1
    .hStopEvent        rd 1
    .lpSourceQueue     rd 1
    .lpTargetPool      rd 1
    .pfnChunkRoutine   rd 1
    .dwChunkCount      rd 1
    .bRunning          rd 1
}