RACCEL_LAST    = 1

macro raccel fFlags, wKey, wCmd, isLast {
    local finalFlags
    finalFlags = fFlags

    if isLast = 1
        finalFlags = finalFlags or 0x80
    end if
    
    dw finalFlags   ; WORD fFlags
    dw wKey         ; WORD wKey
    dw wCmd         ; WORD wCmd
    dw 0            ; WORD padding
}