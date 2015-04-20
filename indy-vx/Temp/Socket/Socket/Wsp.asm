; �������� ������ ��� WSPSocket �� NL = 2.
;
; (c) Indy, 2011.
;
	.686
	.model flat, stdcall
	option casemap :none
	
	include \masm32\include\ntdll.inc
	includelib \masm32\lib\ntdll.lib
	
.code
	include VirXasm32b.asm

	include Img.asm

APIS struct
pRtlCreateUnicodeStringFromAsciiz	PVOID ?	; 0x059B88A67
pRtlFreeUnicodeString			PVOID ?	; 0x0DB164279
pLdrLoadDll					PVOID ?	; 0x09E1E35CE
pLdrUnloadDll					PVOID ?	; 0x0810815B0
pZwAllocateVirtualMemory			PVOID ?	; 0x024741E13
pZwProtectVirtualMemory			PVOID ?	; 0x039542311
pZwFreeVirtualMemory			PVOID ?	; 0x0DA44E712
pZwAreMappedFilesTheSame			PVOID ?	; 0x07CA4251F
pRtlInitUnicodeString			PVOID ?	; 0x0C9167C79
Eol							PVOID ?
APIS ends
PAPIS typedef ptr APIS

%PREGENHASH macro HashList:VARARG
Local Iter, PrevHash
   Iter = 0
   for Hash, <HashList>
      if Iter eq 0
         xor eax,eax
         sub eax,-Hash
      elseif (Iter eq 1) or (Iter eq 3)
         xor eax,(PrevHash xor Hash)
      elseif Iter eq 2
         add eax,dword ptr (Hash - PrevHash)
      elseif Iter eq 4
         sub eax,dword ptr (PrevHash - Hash)
      endif
      stosd
      Iter = Iter + 1
      PrevHash = Hash
      if Iter eq 5
         Iter = 1
      endif
   endm
endm

%POSTGENHASH macro FirstHash, HashList:VARARG
Local Iter, PrevHash
   Iter = 0
   PrevHash = FirstHash
   for Hash, <HashList>
      if (Iter eq 0) or (Iter eq 2)
         xor eax,(PrevHash xor Hash)
      elseif Iter eq 1
         add eax,dword ptr (Hash - PrevHash)
      elseif Iter eq 3
         sub eax,dword ptr (PrevHash - Hash)
      endif
      stosd
      Iter = Iter + 1
      PrevHash = Hash
      if Iter eq 4
         Iter = 0
      endif
   endm
endm

InitializeApis proc uses edi List:PAPIS
	mov edi,List
	cld
%PREGENHASH 59B88A67H, \
	0DB164279H, \
	09E1E35CEH, \
	0810815B0H, \
	024741E13H, \
	039542311H, \
	0DA44E712H, \
	07CA4251FH, \
	0C9167C79H
;%POSTGENHASH 0C9167C79H \
;	...
	xor eax,eax
	stosd	; EOL
	invoke LdrEncodeEntriesList, Eax, Eax, List
	ret
InitializeApis endp

	include GCBE\Bin\Gcbe.inc

OP_MOVS	equ 0A5H

CALLBACK_DATA struct
pIsSameImage	PVOID ?
Data			PVOID ?
CALLBACK_DATA ends
PCALLBACK_DATA typedef ptr CALLBACK_DATA

; o GCBE_PARSE_SEPARATE
;
xWspQuerySockProcTableTraceCallback:
	%GET_CURRENT_GRAPH_ENTRY
WspQuerySockProcTableTraceCallback proc uses ebx esi edi GpEntry:PVOID, ClbkData:PCALLBACK_DATA
	mov edi,GpEntry
	assume edi:PBLOCK_HEADER
	test dword ptr [edi + EhEntryType],TYPE_MASK
	mov ebx,[edi].Address
	jne Next
; Line
	cmp byte ptr [ebx],0BEH	; mov esi,offset SockProcTable
	jne Next
	mov eax,[edi].Link.Flink
	assume eax:PBLOCK_HEADER
	and eax,NOT(TYPE_MASK)
	mov ecx,[eax].Address
	test dword ptr [eax + EhEntryType],TYPE_MASK
	jne Next
	cmp [eax]._Size,2
	jne Next
	cmp word ptr [ecx],PREFIX_REP or (OP_MOVS shl 8)	; rep movsd
	jne Next
	mov ebx,dword ptr [ebx + 1]	; @SockProcTable
	mov esi,ClbkData
	assume esi:PCALLBACK_DATA
	push ecx
	push ebx
	Call [esi].pIsSameImage	; NtAreMappedFilesTheSame
	test eax,eax
	jnz Next	; STATUS_NOT_SAME_DEVICE/STATUS_INVALID_ADDRESS
Back:
	mov edi,[edi].Link.Blink
	and edi,NOT(TYPE_MASK)
	jz Next
	test dword ptr [edi + EhEntryType],TYPE_MASK
	mov eax,[edi].Address
	jnz Next
	cmp byte ptr [eax],0B9H	; mov ecx,#
	jne @f
	cmp dword ptr [eax + 4],30
	jne Next
Store:
	mov [esi].Data,ebx
	mov eax,STATUS_MORE_ENTRIES
	jmp Exit	
@@:
	cmp byte ptr [eax],59H	; pop ecx
	jne Back
	mov edi,[edi].Link.Blink
	and edi,NOT(TYPE_MASK)
	jz Next
	cmp [edi]._Size,2
	mov eax,[edi].Address
	jne Next
	cmp word ptr [eax],1E6AH	; push byte 30
	je Store
Next:
	xor eax,eax
Exit:
	ret
WspQuerySockProcTableTraceCallback endp

; o GCBE_PARSE_SEPARATE
;
xWspParseWSPSocketTraceCallback:
	%GET_CURRENT_GRAPH_ENTRY
WspParseWSPSocketTraceCallback proc uses ebx esi edi GpEntry:PVOID, ClbkData:PCALLBACK_DATA
	mov ebx,GpEntry
	assume ebx:PBLOCK_HEADER
	test dword ptr [ebx + EhEntryType],TYPE_MASK
	mov esi,[ebx].Address
	jne Next
; Line
	cmp byte ptr [esi],68H	; push PWCHAR "\Device\Afd\Endpoint"
	jne Next
	push esi
	mov edi,ClbkData
	assume edi:PCALLBACK_DATA
	mov esi,dword ptr [esi + 1]	; PWCHAR 
	push esi
	Call [edi].pIsSameImage
	test eax,eax
	lea ecx,[esi + 28H]
	jnz Next
	push ecx
	push esi
	Call [edi].pIsSameImage
	test eax,eax
	jnz Next
	invoke LdrCalculateHash, Eax, Esi, 28H
	cmp eax,3E2B0DF4H	; HASH("\Device\Afd\Endpoint")
	jne Next
Scan:
	mov ebx,[ebx].Link.Flink
	and ebx,NOT(TYPE_MASK)
	jz Next
	mov eax,dword ptr [ebx + EhEntryType]
	and eax,TYPE_MASK
	cmp eax,HEADER_TYPE_CALL
	jne Scan
	assume ebx:PCALL_HEADER
	mov eax,[ebx].Address
	cmp word ptr [eax],015FFH
	jne Next
	mov eax,dword ptr [eax + 2]
	mov eax,dword ptr [eax]	; @RtlInitUnicodeString
	cmp [edi].Data,eax
	jne Next
	mov [edi].Data,ebx
	mov eax,STATUS_MORE_ENTRIES
	jmp Exit
Next:
	xor eax,eax
Exit:
	ret
WspParseWSPSocketTraceCallback endp

PARSE_DATA struct
Snapshot	GP_SNAPSHOT <>
WsHandle	HANDLE ?
PARSE_DATA ends
PPARSE_DATA typedef ptr PARSE_DATA

Public DBG_LdrLoadDll
Public DBG_GP_PARSE_WSPStartup
Public DBG_GP_TRACE_WSPStartup
Public DBG_GP_PARSE_WSPSocket
Public DBG_GP_TRACE_WSPSocket

; +
; ���� ������� ������� ACCESSED_MASK_FLAG.
; ������ ����������� ������������ ������ �����.
; ����� ����������� ����� ������ ���������.
;
GpCleaningCycle proc Snapshot:PGP_SNAPSHOT
	mov eax,Snapshot
	mov ecx,GP_SNAPSHOT.GpLimit[eax]
	mov eax,GP_SNAPSHOT.GpBase[eax]
@@:
	and dword ptr [eax + EhAccessFlag],NOT(ACCESSED_MASK_FLAG)
	add eax,ENTRY_HEADER_SIZE
	cmp eax,ecx
	jb @b
	xor eax,eax
	ret
GpCleaningCycle endp

$DllName	CHAR "E:\Mudule\win7_6956\mswsock (1).dll",0

; +
; �����, �������� ������ � ��������� WSPSocket().
;
; o ������� ������ ������ � ������ ������ ���������������.
; o ������ ����� �� � ������������.
; o �� �������� ����.
; o ����� �� ������������(GCBE_PARSE_SEPARATE).
; o ����������� �����������, ��������� ������� ������� ACCESSED_MASK_FLAG.
; o ��������� ���� ������� ACCESSED_MASK_FLAG ��� ��������: 
;   - GP_TRACE
;   - GP_CHECK_IP_BELONG_TO_SNAPSHOT
;   - GP_FIND_CALLER_BELONG_TO_SNAPSHOT
;   - GP_SWITCH_THREAD
; o ���� �� �������������, ����� �� ������������ ��� �������������.
; o ����� �������������� �������(�� �����������).
; o ������ �� �������� Ip. ������ ���������� � ������ ���������.
; o ��������� ������ � NtAreMappedFilesTheSame.
; o �������� ������ ����������� LdrLoadDll(). ���������(�������� ����. ������ �� ������ ����) �� ������������.
; o STPT �� ������������.
; o ���������� ���� ����� �� LDR.
; 
WspInitialize proc uses ebx esi edi Apis:PAPIS, Result:PPARSE_DATA
Local $WsName[12]:CHAR, WsName:UNICODE_STRING
Local WsHandle:PVOID, Wsp[2]:PVOID
Local GpSize:ULONG, Snapshot:GP_SNAPSHOT
Local ClbkData:CALLBACK_DATA
	Call SEH_Epilog_Reference
	Call SEH_Prolog
	xor eax,eax
	mov ebx,Apis
	assume ebx:PAPIS
	mov Snapshot.GpBase,eax
	mov GpSize,100H * X86_PAGE_SIZE
	lea eax,GpSize
	lea ecx,Snapshot.GpBase
	push PAGE_READWRITE
	push MEM_COMMIT
	push eax
	push 0
	push ecx
	push NtCurrentProcess
	Call [ebx].pZwAllocateVirtualMemory
	test eax,eax
	mov esi,Snapshot.GpBase
	jnz Exit
	add Snapshot.GpBase,0FFH * X86_PAGE_SIZE
	mov GpSize,X86_PAGE_SIZE
	lea eax,Snapshot.GpLimit	; Old protect.
	lea ecx,GpSize
	lea edx,Snapshot.GpBase
	push eax
	push PAGE_NOACCESS
	push ecx
	push edx
	push NtCurrentProcess
	Call [ebx].pZwProtectVirtualMemory
	test eax,eax
	mov Snapshot.GpLimit,esi
	mov Snapshot.GpBase,esi
	jnz Free
	lea ecx,$WsName
	lea edx,WsName
	mov dword ptr [$WsName],"swsm"
	push ecx
	mov dword ptr [$WsName + 4],".kco"
	push edx
	mov dword ptr [$WsName + 2*4],"lld"
	Call [ebx].pRtlCreateUnicodeStringFromAsciiz	; "mswsock.dll"
	test eax,eax
	lea ecx,WsHandle
	lea edx,WsName
	.if Zero?
	   mov eax,STATUS_INVALID_PARAMETER
	   jmp Free
	.endif
	push ecx
	push edx
	push NULL
	push NULL
DBG_LdrLoadDll::
	Call [ebx].pLdrLoadDll
	lea ecx,WsName
	push eax
	push ecx
	Call [ebx].pRtlFreeUnicodeString
	pop eax
	mov Wsp[0],60F8831FH	; HASH("WSPStartup")
	test eax,eax
	mov Wsp[4],eax
	jnz Free
	invoke LdrEncodeEntriesList, WsHandle, 0, addr Wsp
	test eax,eax
	lea ecx,Snapshot.GpLimit
	jnz Unload
	push eax
	push eax
	push eax
	push eax
	push eax
	push eax	; !NL
	push GCBE_PARSE_IPCOUNTING or GCBE_PARSE_SEPARATE
	push ecx
	push Wsp[0]
DBG_GP_PARSE_WSPStartup::
; ��������� ������ ����� ����������� �����������.
; ����������� ��������� ���� �������, �� ���� ����� ������ �������������.
	%GPCALL GP_PARSE	; !OPT_EXTERN_SEH_MASK - ����������� ����� �� ����������.
	test eax,eax
	lea ecx,ClbkData
	mov edx,[ebx].pZwAreMappedFilesTheSame
	jnz Unload	; #AV etc.
	mov ClbkData.Data,eax
	mov ClbkData.pIsSameImage,edx
; ���� �� ��������, ������ �����������, �� ���������������� �������.
	push ecx
	%GET_GRAPH_ENTRY xWspQuerySockProcTableTraceCallback
	push eax
	push esi
DBG_GP_TRACE_WSPStartup::
	%GPCALL GP_TRACE
	test eax,eax
	mov ecx,ClbkData.Data
	jz Error
	cmp eax,STATUS_MORE_ENTRIES
	jne Unload
	mov edi,dword ptr [ecx + 28*4]	; WSPSocket()
	push WsHandle
	push edi
	Call [ebx].pZwAreMappedFilesTheSame
	test eax,eax
	lea ecx,Snapshot.GpLimit
	jnz Unload
	mov Snapshot.GpLimit,esi
	push eax
	push eax
	push eax
	push eax
	push eax
	push 2	; NL
	push GCBE_PARSE_IPCOUNTING or GCBE_PARSE_SEPARATE
	push ecx
	push edi
DBG_GP_PARSE_WSPSocket::
	%GPCALL GP_PARSE	; !OPT_EXTERN_SEH_MASK
	test eax,eax
	lea ecx,ClbkData
	mov edx,[ebx].pRtlInitUnicodeString
	jnz Unload	; #AV etc.
	mov Snapshot.Ip,edi
	mov ClbkData.Data,edx
	push ecx
	%GET_GRAPH_ENTRY xWspParseWSPSocketTraceCallback
	push eax
	push esi
DBG_GP_TRACE_WSPSocket::
	%GPCALL GP_TRACE
	test eax,eax
	jz Error
	cmp eax,STATUS_MORE_ENTRIES
	jne Unload
	invoke GpCleaningCycle, addr Snapshot
	mov edi,Result
	mov eax,Snapshot.Ip
	mov ecx,Snapshot.GpBase
	mov edx,Snapshot.GpLimit
	mov esi,WsHandle
	assume edi:PPARSE_DATA
	mov [edi].Snapshot.Ip,eax
	mov [edi].Snapshot.GpBase,ecx
	mov [edi].Snapshot.GpLimit,edx
	mov [edi].WsHandle,esi
	xor eax,eax
	jmp Exit
Error:
	mov eax,STATUS_NOT_FOUND
Unload:
	assume ebx:PAPIS
; Deref.
	push eax
	push WsHandle
	Call [ebx].pLdrUnloadDll
	pop eax
Free:
	push eax
	mov GpSize,NULL
	lea eax,GpSize
	lea ecx,Snapshot.GpBase
	push MEM_RELEASE
	push eax
	push ecx
	push NtCurrentProcess
	Call [ebx].pZwFreeVirtualMemory
	pop eax
	jmp Exit
SEH_Epilog_Reference:
	%GET_CURRENT_GRAPH_ENTRY
Exit:
	Call SEH_Epilog
	ret
WspInitialize endp

$Msg		CHAR "WSPSocket(): 0x%p, SnapBase: 0x%p, SnapLimit: 0x%p, WsHandle: 0x%p", 13, 10, 0

%NTERR macro
	.if Eax
		Int 3
	.endif
endm

Ip proc
Local Api:APIS
Local ParseData:PARSE_DATA
	invoke InitializeApis, addr Api
	%NTERR
	invoke WspInitialize, addr Api, addr ParseData
	%NTERR
	invoke DbgPrint, addr $Msg, ParseData.Snapshot.Ip, ParseData.Snapshot.GpBase, ParseData.Snapshot.GpLimit, ParseData.WsHandle
	ret
Ip endp
end Ip