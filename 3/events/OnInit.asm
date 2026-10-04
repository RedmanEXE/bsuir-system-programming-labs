    mov       ebx, [cmWindow.hWindow]

    ; Create UI for window
    ; Image view control
    stdcall   ImageView.CreateView, ebx, IDC_IMAGE_VIEW, 10, 10, 180, 145
    mov       [hImageView], eax

    ; Load button
    stdcall   Button.CreateButton, ebx, IDC_BUTTON_LOAD, 205, 10, 105, 25,\
              szLoadButtonText, [cmApplication.hSystemFont]
    mov       [hLoadBtn], eax

    ; Save button
    stdcall   Button.CreateButton, ebx, IDC_BUTTON_SAVE, 205, 45, 105, 25,\
              szSaveButtonText, [cmApplication.hSystemFont]
    mov       [hSaveBtn], eax
    stdcall   Button.SetEnabled, [hSaveBtn], FALSE

    ; Speed trackbar (0..2000 ms, step 50 ms)
    stdcall   TrackBar.CreateTrackbar, ebx, IDC_TRACKBAR_SPEED, 205, 80, 105, 30,\
              SPEED_MIN_MS, SPEED_MAX_MS, SPEED_STEP_MS
    mov       [hSpeedTrackbar], eax
    stdcall   TrackBar.SetPos, [hSpeedTrackbar], [dwTransformDelayMs]

    ; Previous button
    stdcall   Button.CreateButton, ebx, IDC_BUTTON_PREVIOUS, 10 , 165, 25, 25,\
              szPrevButtonText, [cmApplication.hSystemFont]
    mov       [hPreviousBtn], eax

    ; Next button
    stdcall   Button.CreateButton, ebx, IDC_BUTTON_NEXT, 165, 165, 25, 25,\
              szNextButtonText, [cmApplication.hSystemFont]
    mov       [hNextBtn], eax

    ; Label with pages count and current page index
    stdcall   TextLabel.CreateLabel, ebx, IDC_TEXT_LABEL_PAGES, 45, 165, 110, 25,\
              szPagesLabelText, SS_CENTER or SS_CENTERIMAGE, [cmApplication.hSystemFont]
    mov       [hPagesLabel], eax
    stdcall   LabThree.MovePage, 0

    ; Initialize processing pipeline
    stdcall   Pipeline.Initialize

    ; Enable Drag'n'Drop
    invoke    DragAcceptFiles, ebx, TRUE
    invoke    DragAcceptFiles, [hImageView], TRUE
