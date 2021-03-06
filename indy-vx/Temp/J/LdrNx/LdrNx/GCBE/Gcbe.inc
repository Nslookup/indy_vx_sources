; o GCBE
; o U/K, MI
; o (c) Indy, 2011.
;
	include Graph.inc

%GPCALL macro Service, Opt
	ifdef Opt
	   mov eax,Service or Opt
	else
	   mov eax,Service
	endif
	Call GCBE
endm

OPT_EXTERN_SEH_MASK		equ 10000000B
OPT_EXTERN_SEH_BIT		equ 7

GP_LDE	equ 0	; ULONG (*PGCBE)(IN PVOID Ip);

GP_PFX	equ 1	; ULONG (*PGCBE)(IN PVOID Ip);

; ����������:
; o Eax ��� ����������(HEADER_TYPE_*).
; o Edx ����� ���������.

GP_PARSE	equ 2

; Flags
GCBE_PARSE_DISCLOSURE	equ 000001B	; �� ������������, ���������� NL.
GCBE_PARSE_SEPARATE		equ 000010B	; ��� ������ ���������� �������� ���������.
GCBE_PARSE_MAKELIST		equ 000100B	; �� ������������ � ������ ������. ������ �������� ������ ��� ����������� �� �����.
GCBE_PARSE_CROSSBREAK	equ 001000B	; �������� ������� �����(��������� �� �� ������ ����������) � �������.
GCBE_PARSE_OPENLIST		equ 010000B	; � ������ �������� ����������� ������ �� CALL_HEADER, ���� ���������� ���� ����, �� �� ������ ���������.
GCBE_PARSE_IPCOUNTING	equ 100000B	; ��������� ����� ���������� � �����. ���� ���� �������, �� ���� IpCount ����� ����������(���������� ��� �������).

; * GCBE_PARSE_CROSSBREAK � GCBE_PARSE_IPCOUNTING �� �������� ��� �������������, ��� ��� ������������ �������� �� ������������������.

; NL
GCBE_PARSE_NL_UNLIMITED	equ -2
GCBE_PARSE_NL_PRIMARY	equ 0

comment '
typedef NTSTATUS (*PPARSE_CALLBACK_ROUTINE)(
   IN PVOID *Graph,		// ������ �� ����.
   IN PVOID GraphEntry,	// ������ �� ��������� ����������.
   IN PVOID SubsList,	// ������ ���������� ������ �������� � ������� ������.
   IN ULONG SubsCount,	// ����� �������� � ������ �������� ������� �����������(NL).
   IN BOOLEAN PreOrPost,	// ��� ������.
   IN PVOID Context
   );

 o ������ �������� ����������� ����(EOL).
 o ��������� ������������ ��������� �� ������� ���������: SubsList[0].BranchLink.
 o ��������� ����� ���������� ���� �������. ����������� ������ ��������� ��� ����������� ��������� ������ ��������� �����.
   * � ��������� ����� ������ ��������� ������ ����� �� ����� ��� ��������(�� ������� �������).
 o �������� ������(Blink) ��������� ����� �������������. ������ ��������� � ����� ��� ������� ���������� ���������.
 o ������ ��������� � ������ ����� ���� �� ��������, �� ����� �������� �� ��������� ������.

typedef PVOID (*PSEARCH_CALLBACK_ROUTINE)(
   IN PVOID Address,
   IN PVOID Context,
   IN BOOLEAN FirstSearch
   );

; o ����� ������� ������� ���� ������ ������ ���� �������� ������������ � Gui-����� ����������� PsConvertToGuiThread(), 
;   ���� ������� ������ �������� �������(����� ����������� �� ��������� ���).

typedef NTSTATUS (*PENTRY)(
  IN PVOID Entry,
  IN OUT PVOID *Graph,
  IN ULONG ParseFlags,
  IN ULONG NestingLevel,
  IN PVOID LastIp OPTIONAL,
  IN PPARSE_CALLBACK_ROUTINE ParseCallbackRoutine OPTIONAL,
  IN PVOID ParseCallbackParameter,
  IN PSEARCH_CALLBACK_ROUTINE SearchCallbackRoutine OPTIONAL,
  IN PVOID SearchCallbackParameter
  );
  '

GP_TRACE	equ 3

comment '
typedef NTSTATUS (*PTRACE_CALLBACK_ROUTINE)(
    IN PVOID GpEntry,
    IN PVOID CallbackParameter
    );

typedef NTSTATUS (*PGCBE)(
  IN PVOID Graph,
  IN ULONG NL,
  IN PTRACE_CALLBACK_ROUTINE CallbackRoutine,
  IN PVOID CallbackParameter
  );
  
 o ����������� ������������ ��������� �� ������� ��������, 
   ��������� �� STATUS_SUCCESS. � ���� ������ ������ ���� 
   �������� ���� ������� ������ ACCESSED_MASK_FLAG �� ����
   ���������� ����� �������� �� �������������, ���� ��� 
   ��������� ��� ������.
  '

GP_BUILD	equ 4

STACK_FRAME struct
Next		PVOID ?	; PSTACK_FRAME
Ip		PVOID ?
STACK_FRAME ends
PSTACK_FRAME typedef ptr STACK_FRAME

GP_CALLER struct
GpEntry		PVOID ?	; 1st
Frame		PSTACK_FRAME ?
SFN			ULONG ?
GP_CALLER ends
PGP_CALLER typedef ptr GP_CALLER

GP_SNAPSHOT struct
Ip		PVOID ?	; ����� ����������� ���������.
GpBase	PVOID ?	; ������� ����� ������ � ������.
GpLimit	PVOID ?	; ����� �����(������ + GpBase).
GP_SNAPSHOT ends
PGP_SNAPSHOT typedef ptr GP_SNAPSHOT

GP_CS_CHECK_IP_BELONG_TO_SNAPSHOT		equ 5

comment '  
typedef NTSTATUS (*PGCBE)(
  IN PGP_SNAPSHOT Snapshot,
  IN PVOID Ip,
  OUT PVOID GraphEntry
  );
  '

GP_RW_CHECK_IP_BELONG_TO_SNAPSHOT		equ 6

comment '  
typedef NTSTATUS (*PGCBE)(
  IN PGP_SNAPSHOT Snapshot,
  IN PVOID NL,
  IN ULONG Ip,
  OUT PVOID GraphEntry
  );
  '

GP_FIND_CALLER_BELONG_TO_SNAPSHOT		equ 7

KernelMode	equ 0
UserMode		equ 1

comment '  
typedef NTSTATUS (*PGCBE)(
  IN PGP_SNAPSHOT Snapshot,
  IN BOOLEAN Raw,
  IN ULONG NL,
  IN PSTACK_FRAME Sfc,
  IN ULONG Mode,
  IN BOOLEAN Trace,
  OUT PGP_CALLER Caller
  );

 o Mode ���������� �����, ���� ������ KernelMode, �� ����������� 
   ������������� ������(����- ��� ����-) ��� �������� ISR.
 o Trace ���������� ��� �����, ���� TRUE, �� Rw.
 '
GP_CS_UNLINK_ENTRY		equ 8
GP_CS_INSERT_HEAD_ENTRY	equ 9
GP_RW_UNLINK_FLOW		equ 10
GP_MERGE				equ 11
GP_SWITCH_THREAD		equ 12