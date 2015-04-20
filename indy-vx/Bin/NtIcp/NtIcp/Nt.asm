; o ������ ��������.
; o Indy Clerk
;
	.686
	.model flat, stdcall
	option casemap :none
	
	include \masm32\include\ntdll.inc
	includelib \masm32\lib\ntdll.lib
	
	include \masm32\include\user32.inc
	includelib \masm32\lib\user32.lib

	include Barrier.asm
	include Apfn.asm

DS_LIMIT		equ 7FFDFH	; ..0x7FFDFFFF

TABLE_MASK	equ 100B
RPL_MASK 		equ 011B

DS_SELECTOR	equ (8H or RPL_MASK or TABLE_MASK)

UsSystemCall		equ 7FFE0300H
UsSystemCallRet	equ 7FFE0304H

MAXIMUM_INSTRUCTION_LENGTH	equ 16

LOAD_REDUCED_DS macro
	push DS_SELECTOR
	pop ds
endm

LOAD_DEFAULT_DS macro
	push KGDT_R3_DATA or RPL_MASK
	pop ds
endm

.data
CallCount		ULONG ?

.code
LeaveStub proc C
	LOAD_REDUCED_DS
	ret
LeaveStub endp

EnterStub proc C
; [Esp]:	@Stub
;		@RefStub
;		p1
;		...
;		pN
	lea edx,[ecx*4 + 4]
	jecxz Stub
@@:
	push dword ptr [esp + edx]
	loop @B
Stub:
	push offset LeaveStub
	push dword ptr [esp + edx]	; @Stub
	push EFLAGS_TF
	LOAD_REDUCED_DS	; ��� �������� �����������..
	popfd
	jmp dword ptr cs:[UsSystemCall]
; [Esp]:	@Stub
;		@LeaveStub
;		p1
;		...
;		pN
;		@Stub
;		@RefStub
;		p1
;		...
;		pN
EnterStub endp

$Message	CHAR "LOG #%p: %p", 13, 10, 0

; +
; VEH
; o �������������� ��� �� ���������, ��� ������ ������� ������ ���������� � �������!
; o ���� ���������� ������� ��������� ���������� �� ����������, ��� ���������� ����
;   �������� ������� ������������, �� ������������ �� ����� ������ Ds � ��������� ��
;   ������, ��������� ������ LOAD_DEFAULT_DS/LOAD_REDUCED_DS!
;
AccessDispatch proc uses esi edi ExceptionPointers:PEXCEPTION_POINTERS
Local BarrierEntry:PVOID, PageSize:ULONG, OldProtect:ULONG
	mov eax,ExceptionPointers
	mov esi,EXCEPTION_POINTERS.ExceptionRecord[eax]
	assume esi:PEXCEPTION_RECORD
	mov edi,EXCEPTION_POINTERS.ContextRecord[eax]
	assume edi:PCONTEXT
	cmp [esi].ExceptionFlags,NULL
	jne Chain
	cmp [esi].ExceptionCode,STATUS_ACCESS_VIOLATION
	je Access
	cmp [esi].ExceptionCode,STATUS_SINGLE_STEP
	jne Chain
	mov eax,dword ptr cs:[UsSystemCall]
	cmp [edi].regEip,eax
	je KiBreak
	jb StopTrace
	add eax,MAXIMUM_INSTRUCTION_LENGTH
	cmp [edi].regEip,eax
	jnb StopTrace
	or [edi].regEFlags,EFLAGS_TF
	jmp ReloadDs
KiBreak:
; Sysenter ��� Int 0x2e.
; ��� �������� �� ������� ����������� Ds. �������������� ���������� ��� �������������� ����������
; (���� ������������), ��� ������� �������� ������� ���� ��������(���������� � � KiUserCallbackD
; ispatcher, Pfn). ��������� ��� ��������� �� �����������, ��� ������� ���������� � ��������� TF.
; ����� ����� ���� �����������. ���������� ��������� ����� �������� � ����(�� KiFastSystemCall) � 
; �����, ��������� ����� �������� �� LeaveStub(). ��� ����� �������� EnterStub().
	mov eax,[edi].regEsp
	xor ecx,ecx
	cmp dword ptr [eax + 4],offset LeaveStub
	mov edx,dword ptr [eax]
	jne @f
	or [edi].regEFlags,EFLAGS_TF
	jmp ReloadDs
@@:
; ooooooooooooooooooooooooooooooooooooooooooooooo
	pushad
; ��������� ����� �������.
; Eip = @KiFastSystemCall/KiIntSystemCall
; Eax = Service ID
	LOAD_DEFAULT_DS
	invoke DbgPrint, addr $Message, CallCount, [edi].regEax
	inc CallCount
	popad
; ooooooooooooooooooooooooooooooooooooooooooooooo
	cmp byte ptr [edx],0C3H	; Ret
	je GoStub
	cmp byte ptr [edx],0C2H	; Ret #
	jne StopTrace	; ����� ���������� �� ����������, �� ��������� �����.
	movzx ecx,word ptr [edx + 1]
GoStub:
	shr ecx,2
	mov [edi].regEip,offset EnterStub
	mov [edi].regEcx,ecx
StopTrace:
	and [edi].regEFlags,NOT(EFLAGS_TF)
	jmp ReloadDs
Access:
; [ExceptionInformation]:
; +0 R/W
; +4 Line address.
	cmp [esi].ExceptionInformation,ACCESS_TYPE_READ
	je @f	; ������ ��� ���������� ��������.
; ������ � �������. (-1 ���� �������� ������ ��� ����� ��������).
	cmp [esi + 4].ExceptionInformation,-1
	jne Chain	; ��������� � �������� ��������, ���������� ����������.
; ��������� �� ������� ��������. ��������� ������� ������.
	cmp [edi].regSegDs,DS_SELECTOR
	jne Chain	; Ds ���������(�� DS_SELECTOR), ��������� �� � �������� ������, ���������� ����������.
	jmp Step	; �������� ��������� � �������� ������, ��������������� Ds � ��������� � ���������� ����������.
@@:
	cmp [esi + 4].ExceptionInformation,-1
	jne IsCallout	; ��������� � �������� ��������, �������� ����� InitRoutine().
	cmp [edi].regSegDs,DS_SELECTOR
	jne Chain	; Ds ���������, ���������� ����������.
; �������� ��������� � UsSharedData. ��������� ����.
IsBreak:
	cmp [edi].regEdx,UsSystemCall
	jne Step
	mov eax,[edi].regEip
	; ..IsValid
	cmp word ptr [eax],12FFH	; call dword ptr ds:[edx]
	jne Step	; �� ����, ��������������� ��������� Ds � ���������� ����������.
; ����� �� �����(ZwXX()).
; ��� ������ ������� ����� ������������� ����������(APC � ��.), ����� ������������ Ds.
	;..
	jmp Step
IsCallout:
	cmp [edi].regEip,80000000H	; ���������� � �������� ����������������� ��(�� Callout).
	jb Chain
; �������� ����� InitRoutine(), ���������.
	mov eax,fs:[TEB.Peb]
	mov eax,PEB.Ldr[eax]
	mov eax,PEB_LDR_DATA.InLoadOrderModuleList[eax]
	mov eax,LDR_DATA_TABLE_ENTRY.InLoadOrderModuleList.Flink[eax]
	mov eax,LDR_DATA_TABLE_ENTRY.EntryPoint[eax]
	cmp [esi].ExceptionAddress,eax
	jne Chain
	cmp [edi].regEip,eax
	jne Chain
; ����� InitRoutine(). ������������ ����� � ������������.
	btr [edi].regEip,31
; Ds ������ ���� ���������, ����� ��������� ����������� ������!
	LOAD_DEFAULT_DS
ReloadDs:
	mov [edi].regSegDs,DS_SELECTOR
Continue:
	mov eax,EXCEPTION_CONTINUE_EXECUTION
Exit:
	ret
Step:
	mov [edi].regSegDs,KGDT_R3_DATA or RPL_MASK
	or [edi].regEFlags,EFLAGS_TF
	jmp Continue
Chain:
	mov [edi].regSegDs,DS_SELECTOR
	LOAD_REDUCED_DS
	xor eax,eax
	jmp Exit
AccessDispatch endp

; +
;
ApfnStub proc C
	LOAD_REDUCED_DS
	ret
ApfnStub endp

; +
; ������ InitRoutine ������ ntdll.dll
; (����� �������� ��������� �� ��������, ����������� Ds).
;
LDR_DILAPIDATE_DATABASE macro
	mov eax,fs:[TEB.Peb]
	mov eax,PEB.Ldr[eax]
	mov eax,PEB_LDR_DATA.InLoadOrderModuleList[eax]
	assume eax:PLDR_DATA_TABLE_ENTRY
	mov eax,[eax].InLoadOrderModuleList.Flink
	bts LDR_DATA_TABLE_ENTRY.EntryPoint[eax],31	; +0x80000000
endm

lpsz	db "..",0

Entry proc
Local ApfnInformation:APFN_INFORMATION
	invoke MessageBeep, 0	; For initialize Apfn.
	invoke ZwSetLdtEntries, DS_SELECTOR, 0FFDFH, 0C7F200H, 0, 0, 0
	test eax,eax
	mov gHandler,offset AccessDispatch
	jnz Exit
	invoke InitializeCalloutEntryListBarrier, addr gBarrier
	test eax,eax
	jnz Exit
	invoke ApfnRedirect, addr ApfnStub, addr ApfnInformation
	test eax,eax
	jnz Exit
	LDR_DILAPIDATE_DATABASE
	invoke MessageBox, 0, addr lpsz, addr lpsz, MB_OK
	LOAD_REDUCED_DS
	invoke ZwYieldExecution	; Break!
Exit:
	ret
Entry endp
end Entry