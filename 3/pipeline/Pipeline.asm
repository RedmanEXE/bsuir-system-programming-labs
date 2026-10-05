; VOID Pipeline.Initialize()
proc Pipeline.Initialize stdcall uses ecx edx ebx esi edi
    locals
        .dwPipeThreadId rd 1
    endl

    ; 1. Create synchronization events
    invoke    CreateEvent, NULL, TRUE, FALSE, NULL
    mov       [hPipelineStopEvent], eax

    invoke    CreateEvent, NULL, FALSE, FALSE, NULL
    mov       [hSubmitPathEvent], eax

    ; 2. Create concurrent ring buffers
    stdcall   ConcurrentRingBuffer.Initialize, sizeof.MLOADTASK, 64
    mov       [hLoadQueue], eax

    stdcall   ConcurrentRingBuffer.Initialize, 4, 64
    mov       [hTransformQueue], eax

    stdcall   ConcurrentRingBuffer.Initialize, sizeof.MSAVETASK, 64
    mov       [hSaveQueue], eax

    ; 3. Create thread pools
    ; Load pool: 2 threads, 64 tasks capacity
    stdcall   ThreadPool.Create, 2, 64
    mov       [hLoadPool], eax

    ; Transform pool: 4 threads, 128 tasks capacity
    stdcall   ThreadPool.Create, 4, 128
    mov       [hTransformPool], eax

    ; 4. Create Task Dispatcher between transform queue and pool
    stdcall   TaskDispatcher.Create, [hTransformQueue], [hTransformPool], 4, Pipeline.TransformChunkProc
    mov       [hTaskDispatcher], eax

    ; 5. Create path pusher thread (hands off file path from UI to load queue)
    lea       eax, [.dwPipeThreadId]
    invoke    CreateThread, NULL, 0, Pipeline.PathPusherThreadProc, 0, 0, eax
    mov       [hPathPusherThread], eax

    ; 6. Create load watcher thread (hands off load task from queue to load pool)
    lea       eax, [.dwPipeThreadId]
    invoke    CreateThread, NULL, 0, Pipeline.LoadWatcherThreadProc, 0, 0, eax
    mov       [hLoadWatcherThread], eax

    ; 7. Create save worker thread
    lea       eax, [.dwPipeThreadId]
    invoke    CreateThread, NULL, 0, Pipeline.SaveWorkerThreadProc, 0, 0, eax
    mov       [hSaveWorkerThread], eax

    ret
endp

; VOID Pipeline.SubmitFile(LPWSTR lpszFilePath)
proc Pipeline.SubmitFile stdcall uses ecx esi edi,\
     lpszFilePath:DWORD
    locals
        .loadTask       MLOADTASK
    endl
    ; Prepare load task
    mov       [.loadTask.dwTaskId], 1
    mov       esi, [lpszFilePath]
    lea       edi, [.loadTask.szFilePath]
    mov       ecx, 260
    cld
      rep movsw

    ; Directly add task to the load queue
    lea       eax, [.loadTask]
    stdcall   ConcurrentRingBuffer.AddItem, [hLoadQueue], eax
    ret
endp

; VOID Pipeline.SubmitSave(LPMIMAGE lpImage, LPWSTR lpszFilePath)
proc Pipeline.SubmitSave stdcall uses ecx esi edi,\
     lpImage:DWORD, lpszFilePath:DWORD
    locals
        .saveTask       MSAVETASK
    endl

    mov       eax, [lpImage]
    mov       [.saveTask.lpImage], eax

    ; Copy path
    mov       esi, [lpszFilePath]
    lea       edi, [.saveTask.szFilePath]
    mov       ecx, 260
    cld
      rep movsw

    ; Ensure .bmp extension
    lea       esi, [.saveTask.szFilePath]
    xor       ecx, ecx
.LenLoop:
    cmp       word [esi + ecx * 2], 0
      je      .LenDone
    inc       ecx
    cmp       ecx, 255
      jb      .LenLoop
.LenDone:
    cmp       ecx, 4
      jb      .AppendExt

    ; Check if ends with .bmp (case-insensitive)
    mov       ax, word [esi + ecx * 2 - 8]
    cmp       ax, '.'
      jne     .AppendExt
    mov       ax, word [esi + ecx * 2 - 6]
    or        ax, 0x20
    cmp       ax, 'b'
      jne     .AppendExt
    mov       ax, word [esi + ecx * 2 - 4]
    or        ax, 0x20
    cmp       ax, 'm'
      jne     .AppendExt
    mov       ax, word [esi + ecx * 2 - 2]
    or        ax, 0x20
    cmp       ax, 'p'
      je      .ExtOk

.AppendExt:
    mov       word [esi + ecx * 2], '.'
    mov       word [esi + ecx * 2 + 2], 'b'
    mov       word [esi + ecx * 2 + 4], 'm'
    mov       word [esi + ecx * 2 + 6], 'p'
    mov       word [esi + ecx * 2 + 8], 0

.ExtOk:
    lea       eax, [.saveTask]
    stdcall   ConcurrentRingBuffer.AddItem, [hSaveQueue], eax
    ret
endp

; DWORD Pipeline.PathPusherThreadProc(LPVOID lpParam)
proc Pipeline.PathPusherThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .waitHandles    MWAITHANDLES2
        .pushTask       MLOADTASK
    endl

    mov       eax, [hPipelineStopEvent]
    mov       [.waitHandles.h0], eax
    mov       eax, [hSubmitPathEvent]
    mov       [.waitHandles.h1], eax

.Loop:
    lea       eax, [.waitHandles]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE

    cmp       eax, WAIT_OBJECT_0
      je      .Exit

    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .Loop

    ; Prepare load task
    mov       [.pushTask.dwTaskId], 1
    mov       esi, szSubmitPathBuffer
    lea       edi, [.pushTask.szFilePath]
    mov       ecx, 260
    cld
      rep movsw

    ; Add to load queue
    lea       eax, [.pushTask]
    stdcall   ConcurrentRingBuffer.AddItem, [hLoadQueue], eax

    jmp       .Loop

.Exit:
    xor       eax, eax
    ret
endp

; DWORD Pipeline.LoadWatcherThreadProc(LPVOID lpParam)
proc Pipeline.LoadWatcherThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .waitHandles    MWAITHANDLES2
        .watchTask      MLOADTASK
    endl

    mov       eax, [hPipelineStopEvent]
    mov       [.waitHandles.h0], eax

    stdcall   ConcurrentRingBuffer.GetWaitHandle, [hLoadQueue]
    mov       [.waitHandles.h1], eax

.Loop:
    lea       eax, [.waitHandles]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE

    cmp       eax, WAIT_OBJECT_0
      je      .Exit

    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .Loop

    ; Pop load task from queue
    lea       eax, [.watchTask]
    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, [hLoadQueue], eax
    test      eax, eax
      jz      .Loop

    ; Allocate task buffer on heap for pool worker
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MLOADTASK
    test      eax, eax
      jz      .Loop

    mov       ebx, eax
    mov       edi, eax
    lea       esi, [.watchTask]
    mov       ecx, sizeof.MLOADTASK
    cld
      rep movsb

    ; Dispatch to load thread pool
    stdcall   ThreadPool.QueueTask, [hLoadPool], Pipeline.LoadWorkerProc, ebx

    jmp       .Loop

.Exit:
    xor       eax, eax
    ret
endp

; VOID Pipeline.LoadWorkerProc(LPVOID lpContext)
proc Pipeline.LoadWorkerProc stdcall uses ecx edx ebx esi edi,\
     lpContext:DWORD
    locals
        .hFile          rd 1
        .dwBytesRead    rd 1
        .dwWidth        rd 1
        .dwHeight       rd 1
        .dwPitch24      rd 1
        .dwSize24       rd 1
        .bTopDown       rd 1
        .lpDstBits      rd 1
        .lpRowBuf       rd 1
        .lpPalette      rd 1
        .lpImg          rd 1
        .bfh            BITMAPFILEHEADER
        .bih            BITMAPINFOHEADER
    endl

    mov       [.hFile], -1
    mov       [.lpDstBits], 0
    mov       [.lpRowBuf], 0
    mov       [.lpPalette], 0
    mov       [.lpImg], 0

    mov       esi, [lpContext]
    test      esi, esi
      jz      .Exit

    virtual at esi
        .task MLOADTASK
    end virtual

    ; Open file for reading
    lea       eax, [.task.szFilePath]
    invoke    CreateFile, eax, GENERIC_READ, FILE_SHARE_READ, NULL,\
              OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp       eax, -1
      je      .FreeTask
    mov       [.hFile], eax

    ; Read BITMAPFILEHEADER
    lea       ecx, [.bfh]
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], ecx, sizeof.BITMAPFILEHEADER, edx, NULL
    test      eax, eax
      jz      .Cleanup
    cmp       [.dwBytesRead], sizeof.BITMAPFILEHEADER
      jne     .Cleanup

    ; Validate 'BM' signature
    cmp       word [.bfh.bfType], 0x4D42
      jne     .Cleanup

    ; Read BITMAPINFOHEADER (first 40 bytes)
    lea       ecx, [.bih]
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], ecx, sizeof.BITMAPINFOHEADER, edx, NULL
    test      eax, eax
      jz      .Cleanup
    cmp       [.dwBytesRead], sizeof.BITMAPINFOHEADER
      jne     .Cleanup

    ; Check supported bit depths (8, 24, 32)
    movzx     eax, word [.bih.biBitCount]
    cmp       eax, 8
      je      .BppSupported
    cmp       eax, 24
      je      .BppSupported
    cmp       eax, 32
      jne     .Cleanup

.BppSupported:
    ; Check width (> 0)
    mov       eax, [.bih.biWidth]
    test      eax, eax
      jle     .Cleanup
    mov       [.dwWidth], eax

    ; Check height (!= 0) and determine orientation (bottom-up vs top-down)
    mov       eax, [.bih.biHeight]
    test      eax, eax
      jz      .Cleanup
      jns     .BottomUp
    neg       eax
    mov       [.bTopDown], 1
    jmp       .HeightDone

.BottomUp:
    mov       [.bTopDown], 0

.HeightDone:
    mov       [.dwHeight], eax

    ; Calculate 24-bpp destination pitch: ((width * 3 + 3) / 4) * 4
    mov       eax, [.dwWidth]
    lea       eax, [eax + eax * 2 + 3]
    and       eax, not 3
    mov       [.dwPitch24], eax

    ; Calculate 24-bpp buffer size: pitch * height
    mul       dword [.dwHeight]
    mov       [.dwSize24], eax

    ; Allocate destination pixel buffer
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], [.dwSize24]
    test      eax, eax
      jz      .Cleanup
    mov       [.lpDstBits], eax

    ; Zero-initialize destination buffer
    mov       edi, eax
    mov       ecx, [.dwSize24]
    shr       ecx, 2
    xor       eax, eax
    cld
    rep       stosd

    ; Validate bfOffBits
    mov       eax, [.bfh.bfOffBits]
    cmp       eax, 54
      jae     @F
    mov       eax, 54
    mov       [.bfh.bfOffBits], eax
@@:

    ; Branch by bit depth
    movzx     eax, word [.bih.biBitCount]
    cmp       eax, 8
      je      .Load8Bpp
    cmp       eax, 32
      je      .Load32Bpp

    ; 24 bpp
    cmp       [.bTopDown], 0
      jne     .Load24BppTopDown

    ; Bottom-up 24bpp: direct read of all bits
    invoke    SetFilePointer, [.hFile], [.bfh.bfOffBits], NULL, FILE_BEGIN
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], [.lpDstBits], [.dwSize24], edx, NULL
    test      eax, eax
      jz      .Cleanup
    jmp       .CreateImage

.Load24BppTopDown:
    invoke    SetFilePointer, [.hFile], [.bfh.bfOffBits], NULL, FILE_BEGIN
    xor       ebx, ebx                 ; ebx = y from 0 to dwHeight - 1
.Row24Loop:
    cmp       ebx, [.dwHeight]
      jae     .CreateImage

    mov       eax, [.dwHeight]
    dec       eax
    sub       eax, ebx
    mul       dword [.dwPitch24]
    add       eax, [.lpDstBits]

    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], eax, [.dwPitch24], edx, NULL
    test      eax, eax
      jz      .Cleanup

    inc       ebx
    jmp       .Row24Loop

.Load32Bpp:
    ; Allocate row buffer: dwWidth * 4
    mov       eax, [.dwWidth]
    shl       eax, 2
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], eax
    test      eax, eax
      jz      .Cleanup
    mov       [.lpRowBuf], eax

    invoke    SetFilePointer, [.hFile], [.bfh.bfOffBits], NULL, FILE_BEGIN

    xor       ebx, ebx                 ; ebx = y from 0 to dwHeight - 1
.Row32Loop:
    cmp       ebx, [.dwHeight]
      jae     .Load32Done

    ; Read 32-bit row into lpRowBuf
    mov       eax, [.dwWidth]
    shl       eax, 2
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], [.lpRowBuf], eax, edx, NULL
    test      eax, eax
      jz      .Cleanup

    ; Calculate dst row address
    mov       eax, ebx
    cmp       [.bTopDown], 0
      je      @F
    mov       eax, [.dwHeight]
    dec       eax
    sub       eax, ebx
@@:
    mul       dword [.dwPitch24]
    add       eax, [.lpDstBits]
    mov       edi, eax                 ; edi = dst row (24 bpp)
    mov       esi, [.lpRowBuf]         ; esi = src row (32 bpp)

    ; Convert BGRA -> BGR
    xor       ecx, ecx                 ; ecx = x from 0 to dwWidth - 1
.Col32Loop:
    cmp       ecx, [.dwWidth]
      jae     .NextRow32

    mov       al, byte [esi]           ; B
    mov       byte [edi], al
    mov       al, byte [esi + 1]       ; G
    mov       byte [edi + 1], al
    mov       al, byte [esi + 2]       ; R
    mov       byte [edi + 2], al

    add       esi, 4
    add       edi, 3
    inc       ecx
    jmp       .Col32Loop

.NextRow32:
    inc       ebx
    jmp       .Row32Loop

.Load32Done:
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpRowBuf]
    mov       [.lpRowBuf], 0
    jmp       .CreateImage

.Load8Bpp:
    ; 1. Allocate palette buffer (1024 bytes for 256 RGBQUADs)
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], 1024
    test      eax, eax
      jz      .Cleanup
    mov       [.lpPalette], eax

    ; Palette is at file offset: 14 + bih.biSize
    mov       eax, [.bih.biSize]
    add       eax, 14
    invoke    SetFilePointer, [.hFile], eax, NULL, FILE_BEGIN

    ; Read 1024 bytes palette
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], [.lpPalette], 1024, edx, NULL
    test      eax, eax
      jz      .Cleanup

    ; 2. Allocate row buffer for 8-bit row: ((dwWidth + 3) / 4) * 4
    mov       eax, [.dwWidth]
    add       eax, 3
    and       eax, not 3
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], eax
    test      eax, eax
      jz      .Cleanup
    mov       [.lpRowBuf], eax

    ; 3. Seek to pixel array
    invoke    SetFilePointer, [.hFile], [.bfh.bfOffBits], NULL, FILE_BEGIN

    xor       ebx, ebx                 ; ebx = y from 0 to dwHeight - 1
.Row8Loop:
    cmp       ebx, [.dwHeight]
      jae     .Load8Done

    ; Read 8-bit row into lpRowBuf
    mov       eax, [.dwWidth]
    add       eax, 3
    and       eax, not 3
    lea       edx, [.dwBytesRead]
    invoke    ReadFile, [.hFile], [.lpRowBuf], eax, edx, NULL
    test      eax, eax
      jz      .Cleanup

    ; Calculate dst row address
    mov       eax, ebx
    cmp       [.bTopDown], 0
      je      @F
    mov       eax, [.dwHeight]
    dec       eax
    sub       eax, ebx
@@:
    mul       dword [.dwPitch24]
    add       eax, [.lpDstBits]
    mov       edi, eax                 ; edi = dst row (24 bpp)
    mov       esi, [.lpRowBuf]         ; esi = src row (8 bpp)

    ; Convert row pixels using palette
    xor       ecx, ecx                 ; ecx = x from 0 to dwWidth - 1
.Col8Loop:
    cmp       ecx, [.dwWidth]
      jae     .NextRow8

    movzx     eax, byte [esi]          ; palette index 0..255
    shl       eax, 2                   ; eax = index * 4
    add       eax, [.lpPalette]        ; eax = pointer to RGBQUAD

    mov       dl, byte [eax]           ; rgbBlue
    mov       byte [edi], dl
    mov       dl, byte [eax + 1]       ; rgbGreen
    mov       byte [edi + 1], dl
    mov       dl, byte [eax + 2]       ; rgbRed
    mov       byte [edi + 2], dl

    inc       esi
    add       edi, 3
    inc       ecx
    jmp       .Col8Loop

.NextRow8:
    inc       ebx
    jmp       .Row8Loop

.Load8Done:
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpRowBuf]
    mov       [.lpRowBuf], 0
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpPalette]
    mov       [.lpPalette], 0
    jmp       .CreateImage

.CreateImage:
    ; Close source file handle
    invoke    CloseHandle, [.hFile]
    mov       [.hFile], -1

    ; Allocate MIMAGE
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MIMAGE
    test      eax, eax
      jz      .Cleanup
    mov       [.lpImg], eax
    mov       edi, eax

    virtual at edi
        .img MIMAGE
    end virtual

    mov       [.img.hBitmap], 0
    mov       eax, [.lpDstBits]
    mov       [.img.lpBits], eax
    mov       eax, [.dwWidth]
    mov       [.img.dwWidth], eax
    mov       eax, [.dwHeight]
    mov       [.img.dwHeight], eax
    mov       eax, [.dwPitch24]
    mov       [.img.dwPitch], eax
    mov       [.img.dwBpp], 24

    mov       [.img.dwChunksTotal], 4
    mov       [.img.dwChunksRemaining], 4

    invoke    CreateEvent, NULL, TRUE, FALSE, NULL
    mov       [.img.hEventComplete], eax

    ; Transfer ownership of lpDstBits to MIMAGE
    mov       [.lpDstBits], 0

    ; Notify main window that image is loaded and ready for display
    invoke    PostMessage, [cmWindow.hWindow], WM_APP_IMAGE_LOADED, edi, 0

    ; Add image to transform queue
    lea       eax, [.lpImg]
    stdcall   ConcurrentRingBuffer.AddItem, [hTransformQueue], eax

    jmp       .FreeTask

.Cleanup:
    cmp       [.lpRowBuf], 0
      je      @F
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpRowBuf]
    mov       [.lpRowBuf], 0
@@:
    cmp       [.lpPalette], 0
      je      @F
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpPalette]
    mov       [.lpPalette], 0
@@:
    cmp       [.lpDstBits], 0
      je      @F
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.lpDstBits]
    mov       [.lpDstBits], 0
@@:
    cmp       [.hFile], -1
      je      .FreeTask
    invoke    CloseHandle, [.hFile]
    mov       [.hFile], -1

.FreeTask:
    mov       esi, [lpContext]
    test      esi, esi
      jz      .Exit
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi

.Exit:
    ret
endp

; VOID Pipeline.TransformChunkProc(LPVOID lpContext)
proc Pipeline.TransformChunkProc stdcall uses ecx edx ebx esi edi,\
     lpContext:DWORD
    locals
        .dwY            rd 1
        .dwX            rd 1
        .lpRow          rd 1
    endl

    mov       esi, [lpContext]
    test      esi, esi
      jz      .End

    virtual at esi
        .chunk MCHUNKTRANSFORMTASK
    end virtual

    mov       edi, [.chunk.lpImage]
    test      edi, edi
      jz      .FreeTask

    virtual at edi
        .img MIMAGE
    end virtual

    mov       edx, [.img.lpBits]
    test      edx, edx
      jz      .CheckCompletion

    mov       eax, [.img.dwBpp]
    cmp       eax, 24
      je      @F
    cmp       eax, 32
      jne     .CheckCompletion
@@:

    ; Process rows from dwStartY to dwEndY
    mov       eax, [.chunk.dwStartY]
    mov       [.dwY], eax

.RowLoop:
    mov       eax, [.dwY]
    cmp       eax, [.chunk.dwEndY]
      jae     .CheckCompletion

    ; Calculate row pointer: lpBits + dwY * dwPitch
    mov       eax, [.dwY]
    mul       dword [.img.dwPitch]
    add       eax, [.img.lpBits]
    mov       [.lpRow], eax

    ; Process pixels in row
    xor       ebx, ebx
.ColLoop:
    cmp       ebx, [.img.dwWidth]
      jae     .NextRow

    ; 24bpp or 32bpp BGR pixel
    mov       edx, [.lpRow]
    mov       eax, [.img.dwBpp]
    cmp       eax, 32
      je      .Pixel32

    ; 24bpp: offset = ebx * 3
    lea       eax, [ebx + ebx * 2]
    add       edx, eax
    jmp       .ConvertBgr

.Pixel32:
    ; 32bpp: offset = ebx * 4
    lea       edx, [edx + ebx * 4]

.ConvertBgr:
    ; Grayscale = (R * 77 + G * 150 + B * 29) >> 8
    movzx     eax, byte [edx]          ; B
    imul      eax, 29
    movzx     ecx, byte [edx + 1]      ; G
    imul      ecx, 150
    add       eax, ecx
    movzx     ecx, byte [edx + 2]      ; R
    imul      ecx, 77
    add       eax, ecx
    shr       eax, 8

    ; Write back grayscale
    mov       byte [edx], al
    mov       byte [edx + 1], al
    mov       byte [edx + 2], al

    inc       ebx
    jmp       .ColLoop

.NextRow:
    inc       dword [.dwY]
    jmp       .RowLoop

.CheckCompletion:
    ; Notify main window that this chunk has been transformed
    invoke    PostMessage, [cmWindow.hWindow], WM_APP_CHUNK_READY, edi, 0

    ; Atomic decrement of chunks remaining
    lock dec  dword [.img.dwChunksRemaining]
      jnz     .FreeTask

    ; All chunks completed
    invoke    SetEvent, [.img.hEventComplete]
    invoke    PostMessage, [cmWindow.hWindow], WM_APP_IMAGE_READY, edi, 0

.FreeTask:
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi
.End:
    ret
endp

; DWORD Pipeline.SaveWorkerThreadProc(LPVOID lpParam)
proc Pipeline.SaveWorkerThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .waitHandles    MWAITHANDLES2
        .saveTask       MSAVETASK
        .hFile          rd 1
        .dwBytesWritten rd 1
        .bfh            BITMAPFILEHEADER
        .bih            BITMAPINFOHEADER
        .dwImageSize    rd 1
    endl

    mov       eax, [hPipelineStopEvent]
    mov       [.waitHandles.h0], eax

    stdcall   ConcurrentRingBuffer.GetWaitHandle, [hSaveQueue]
    mov       [.waitHandles.h1], eax

.Loop:
    lea       eax, [.waitHandles]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE

    cmp       eax, WAIT_OBJECT_0
      je      .Exit

    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .Loop

    ; Pop save task
    lea       eax, [.saveTask]
    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, [hSaveQueue], eax
    test      eax, eax
      jz      .Loop

    mov       esi, [.saveTask.lpImage]
    test      esi, esi
      jz      .Loop

    virtual at esi
        .img MIMAGE
    end virtual

    ; Calculate raw image size: dwPitch * dwHeight
    mov       eax, [.img.dwPitch]
    mul       dword [.img.dwHeight]
    mov       [.dwImageSize], eax

    ; Setup BITMAPFILEHEADER
    mov       word [.bfh.bfType], 0x4D42 ; 'BM'
    mov       eax, [.dwImageSize]
    add       eax, sizeof.BITMAPFILEHEADER + sizeof.BITMAPINFOHEADER
    mov       [.bfh.bfSize], eax
    mov       word [.bfh.bfReserved1], 0
    mov       word [.bfh.bfReserved2], 0
    mov       dword [.bfh.bfOffBits], sizeof.BITMAPFILEHEADER + sizeof.BITMAPINFOHEADER

    ; Setup BITMAPINFOHEADER
    mov       [.bih.biSize], sizeof.BITMAPINFOHEADER
    mov       eax, [.img.dwWidth]
    mov       [.bih.biWidth], eax
    mov       eax, [.img.dwHeight]
    mov       [.bih.biHeight], eax
    mov       word [.bih.biPlanes], 1
    mov       ax, word [.img.dwBpp]
    mov       word [.bih.biBitCount], ax
    mov       [.bih.biCompression], BI_RGB
    mov       eax, [.dwImageSize]
    mov       [.bih.biSizeImage], eax
    mov       [.bih.biXPelsPerMeter], 0
    mov       [.bih.biYPelsPerMeter], 0
    mov       [.bih.biClrUsed], 0
    mov       [.bih.biClrImportant], 0

    ; Create destination file
    lea       eax, [.saveTask.szFilePath]
    invoke    CreateFile, eax, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    cmp       eax, -1
      je      .Loop
    mov       [.hFile], eax

    ; Write BITMAPFILEHEADER
    lea       eax, [.dwBytesWritten]
    lea       ecx, [.bfh]
    invoke    WriteFile, [.hFile], ecx, sizeof.BITMAPFILEHEADER, eax, NULL

    ; Write BITMAPINFOHEADER
    lea       eax, [.dwBytesWritten]
    lea       ecx, [.bih]
    invoke    WriteFile, [.hFile], ecx, sizeof.BITMAPINFOHEADER, eax, NULL

    ; Write pixel bits
    lea       eax, [.dwBytesWritten]
    invoke    WriteFile, [.hFile], [.img.lpBits], [.dwImageSize], eax, NULL

    invoke    CloseHandle, [.hFile]

    ; Notify main window
    invoke    PostMessage, [cmWindow.hWindow], WM_APP_IMAGE_SAVED, esi, 0

    jmp       .Loop

.Exit:
    xor       eax, eax
    ret
endp

; VOID Pipeline.Destroy()
proc Pipeline.Destroy stdcall uses ecx edx ebx esi edi
    locals
        .waitThreads    MWAITHANDLES3
    endl

    ; 1. Signal stop event to all pipeline threads
    cmp       [hPipelineStopEvent], 0
      je      .End
    invoke    SetEvent, [hPipelineStopEvent]

    ; 2. Wait for pipeline input/output worker threads
    mov       eax, [hPathPusherThread]
    mov       [.waitThreads.h0], eax
    mov       eax, [hLoadWatcherThread]
    mov       [.waitThreads.h1], eax
    mov       eax, [hSaveWorkerThread]
    mov       [.waitThreads.h2], eax

    lea       eax, [.waitThreads]
    invoke    WaitForMultipleObjects, 3, eax, TRUE, 5000

    invoke    CloseHandle, [hPathPusherThread]
    mov       [hPathPusherThread], 0
    invoke    CloseHandle, [hLoadWatcherThread]
    mov       [hLoadWatcherThread], 0
    invoke    CloseHandle, [hSaveWorkerThread]
    mov       [hSaveWorkerThread], 0

    ; 3. Stop Task Dispatcher (waits for dispatcher thread to terminate)
    cmp       [hTaskDispatcher], 0
      je      @F
    stdcall   TaskDispatcher.Destroy, [hTaskDispatcher]
    mov       [hTaskDispatcher], 0
@@:
    ; 4. Stop Thread Pools (waits for all worker threads to terminate)
    cmp       [hTransformPool], 0
      je      @F
    stdcall   ThreadPool.Destroy, [hTransformPool]
    mov       [hTransformPool], 0
@@:
    cmp       [hLoadPool], 0
      je      @F
    stdcall   ThreadPool.Destroy, [hLoadPool]
    mov       [hLoadPool], 0
@@:
    ; 5. Detach current image from ImageView to prevent painting freed memory
    cmp       [hImageView], 0
      je      @F
    invoke    SetWindowLong, [hImageView], GWL_USERDATA, 0
@@:
    mov       [cmApplication.lpCurrentImage], 0

    ; 6. Clean up all loaded images (all background threads have terminated)
    xor       ebx, ebx
.FreeImgLoop:
    movzx     edx, word [dwPages + 2]
    cmp       ebx, edx
      jae     .NoLoadedImages

    mov       esi, [lpImagesList + ebx * 4]
    mov       dword [lpImagesList + ebx * 4], 0
    test      esi, esi
      jz      .NextImg

    virtual at esi
        .imgToFree MIMAGE
    end virtual

    cmp       [.imgToFree.hEventComplete], 0
      je      @F
    invoke    CloseHandle, [.imgToFree.hEventComplete]
@@:
    cmp       [.imgToFree.lpBits], 0
      je      @F
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.imgToFree.lpBits]
@@:
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi

.NextImg:
    inc       ebx
    jmp       .FreeImgLoop

.NoLoadedImages:
    mov       word [dwPages + 2], 0
    mov       word [dwPages], 0

    ; 7. Destroy queues
    cmp       [hSaveQueue], 0
      je      @F
    stdcall   ConcurrentRingBuffer.Destroy, [hSaveQueue]
    mov       [hSaveQueue], 0
@@:
    cmp       [hTransformQueue], 0
      je      @F
    stdcall   ConcurrentRingBuffer.Destroy, [hTransformQueue]
    mov       [hTransformQueue], 0
@@:
    cmp       [hLoadQueue], 0
      je      @F
    stdcall   ConcurrentRingBuffer.Destroy, [hLoadQueue]
    mov       [hLoadQueue], 0
@@:
    ; 8. Close synchronization events
    cmp       [hSubmitPathEvent], 0
      je      @F
    invoke    CloseHandle, [hSubmitPathEvent]
    mov       [hSubmitPathEvent], 0
@@:
    cmp       [hPipelineStopEvent], 0
      je      @F
    invoke    CloseHandle, [hPipelineStopEvent]
    mov       [hPipelineStopEvent], 0
@@:

.End:
    ret
endp
