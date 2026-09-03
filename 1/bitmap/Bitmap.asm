; HBITMAP Bitmap.LoadImage(char *lpszPath);
Bitmap.LoadImage:
    push      ebp
    mov       ebp, esp

    invoke    LoadImage, NULL, dword [ebp + 8], IMAGE_BITMAP, 0, 0,\
              LR_DEFAULTCOLOR or LR_LOADFROMFILE

    leave
    ret       4
