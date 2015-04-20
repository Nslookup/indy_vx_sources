	.686
	.model flat, stdcall
	option casemap :none
	
	include \masm32\include\ntdll.inc
		
	include \masm32\include\user32.inc
	includelib \masm32\lib\user32.lib
	
_imp__EnumDisplayMonitors proto :dword, :dword, :dword, :dword

.code
; +
; ���������� ���������.
; o Eax: ID NtUserEnumDisplayMonitors.
; o Esi: ����� ��������.
; o Edi: ������ �� ����.
;
TsSave proc C
	xor ecx,ecx
	push esp	; �������� ��� ������� - ������ �� ���� ��� ��� ��������������.
	Call @f	; ������ �� ������.
; ������.
; typedef BOOL (CALLBACK* MONITORENUMPROC)(HMONITOR, HDC, LPRECT, LPARAM);
	mov esp,dword ptr [esp + 4*4]	; ��������������� ����, ������ ��� �������������� ��������� ����������.
	xor eax,eax
	retn
@@:
	push ecx
	push ecx
	mov edx,esp
; BOOL
; NtUserEnumDisplayMonitors(
;     IN HDC             hdc,
;     IN LPCRECT         lprcClip,
;     IN MONITORENUMPROC lpfnEnum,
;     IN LPARAM          dwData)
	Int 2EH	; NtUserEnumDisplayMonitors
; ��� �������������� ��������� ������������ �� ����.
	.if !Eax	; ������ �� ��� ������ ���� ���������� ������ �������/�����������(0x2C).
	add esp,4*4	; ������� ��������� �������.
	mov eax,STATUS_STACK_OVERFLOW
	retn
	.else
	mov esp,edi
	add eax,3*4	; ������ �� ����, ������� ��� ��� ������ TsLoad(��� �������� ����������).
	jmp esi
	.endif
TsSave endp

; +
; �������������� ���������.
;
TsLoad proc C	; stdcall
	xor eax,eax
	mov edx,3*4
	push eax
	push eax
	push esp
	mov ecx,esp
	Int 2BH
	add esp,3*4
	retn		; � ������ ������ ��������� STATUS_NO_CALLBACK_ACTIVE.
TsLoad endp

Entry proc
	lea esi,offset cbRet
	mov edi,esp
	nop
	nop
	nop
	mov eax,dword ptr [_imp__EnumDisplayMonitors]	; ����.
	mov eax,dword ptr [eax + 1]	; ID NtUserEnumDisplayMonitors
	Call TsSave
	db 32 dup (90H)
	Call TsLoad
	int 3
	db 32 dup (90H)
cbRet:
	ret
Entry endp
end Entry