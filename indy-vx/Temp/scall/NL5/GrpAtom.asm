MPH_HANDLER_ENTRY struct
Ip		PVOID ?	; ����� �������������� ��������.
Gp		PVOID ?	; ���� ����� ������������ �������.
MPH_HANDLER_ENTRY ends
PENTRY typedef ptr ENTRY

MIP_MAX_IPS	equ 128	; ������������ ����� �������������� ����������.

MIP_STATUS_HANDLED	equ 1

ifdef OPT_ENABLE_DBG_LOG
	$MIP_MORPH_ATOMIC	CHAR "MIP_MORPH_ATOMIC.GpKit: 0x%X", CRLF
endif

; +
; ���� �������� ���������� �� ����������� ���������.
;
; o GCBE_PARSE_SEPARATE, �������� ����.
; o �������������� ����������� ������.
; o ��� ������� ��������� ���������� ������, �������� �����������.
; o � ������ ������� ������ �� ���������� ����� �����, ����� �� ����� ���������� ��������� ���������� �������� � ����.
;
; typedef MIP_STATUS (*PIDENT_CALLBACK)(
;   IN PVOID GraphEntry,
;   IN PVOID *GpBase,
;   IN PVOID *GpLimit,
;   OUT PVOID *Ip,
;   IN PVOID Context
;   );
;
; LocalDispatch - ������� ����������. ���� ��������(TRUE), �� � �������� ���� �� ���������� ��������� ���������.
;
; o AccessFlag ������ ���� ������!
;
MIP_MORPH_ATOMIC proc uses ebx esi edi GpBase:PVOID, GpLimit:PVOID, LocalDispatch:BOOLEAN, IdentClbk:PVOID, ClbkArg:PVOID
Local Mph[MIP_MAX_IPS]:MPH_HANDLER_ENTRY
Local MphCount:ULONG
Local Ip:PVOID
Local Recursion:BOOLEAN
	mov MphCount,0
Scan:
	mov esi,GpLimit
	mov ebx,GpBase
	mov Recursion,FALSE
	mov edi,dword ptr [esi]
Check:
	lea eax,Ip
	push ClbkArg
	push eax
	push GpLimit
	push GpBase
	push ebx
	Call IdentClbk
	test eax,eax	; Status
	jz Next
	cmp eax,MIP_STATUS_HANDLED
	mov ecx,MphCount
	jne Exit
	mov eax,Ip
	and dword ptr [ebx + EhEntryType],NOT(TYPE_MASK)
	mov dword ptr [ebx + EhBranchAddress],eax
	or dword ptr [ebx + EhEntryType],ENTRY_TYPE_CALL
	or dword ptr [ebx + EhVirtFlag],VIRT_IP_MASK
	.if LocalDispatch
		inc MphCount
		mov dword ptr [ebx + EhBranchLink],NULL
		and dword ptr [ebx + EhDisclosureFlag],NOT(DISCLOSURE_CALL_FLAG)
		or dword ptr [ebx + EhBranchType],BRANCH_DEFINED_FLAG
		jmp Next
	.endif
	test ecx,ecx
	mov edx,GpLimit
	.if !Zero?
		.repeat
; ���� ��������������� ���� � �������, �������� ������� ��� ��� ������ ������.
			cmp Mph.Ip[ecx * sizeof(MPH_HANDLER_ENTRY) - sizeof(MPH_HANDLER_ENTRY)],eax
			je GpOld
			dec ecx
		.until Zero?
	.endif
	push ecx
	push ecx
	push ecx
	push ecx
	push ecx
	push GCBE_PARSE_NL_UNLIMITED
	push GCBE_PARSE_SEPARATE or GCBE_PARSE_IPCOUNTING
	mov edx,dword ptr [edx]
	mov ecx,MphCount
	push GpBase
	push GpLimit
	push eax
	mov Mph.Ip[ecx * sizeof(MPH_HANDLER_ENTRY)],eax
	mov Mph.Gp[ecx * sizeof(MPH_HANDLER_ENTRY)],edx
	inc MphCount
	mov Recursion,TRUE
	Call GpKit
	%DBG $MIP_MORPH_ATOMIC, Eax
	test eax,eax
	mov ecx,MphCount
	jnz Exit
GpOld:
	mov edx,Mph.Gp[ecx * sizeof(MPH_HANDLER_ENTRY) - sizeof(MPH_HANDLER_ENTRY)]
	mov dword ptr [ebx + EhBranchLink],edx
	or dword ptr [ebx + EhDisclosureFlag],DISCLOSURE_CALL_FLAG
	or dword ptr [ebx + EhBranchType],BRANCH_DEFINED_FLAG
Next:
	add ebx,ENTRY_SIZE
	cmp ebx,edi
	jb Check
	cmp Recursion,FALSE
	jne Scan
	xor eax,eax
Exit:
	ret
MIP_MORPH_ATOMIC endp