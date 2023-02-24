%macro print 3				;first argument is stream(stdout/stderr), second argument is the printing format, third argument is the pointer to the stream to print
	pushad
	push dword %3			;pushing the third argument to the stack
	push %2
	push dword[%1]	
	call fprintf
	add esp,12
	popad
%endmacro

%macro read_input 0
	pushad
	push dword[stdin]
	push max_size
	push buffer
	call fgets
	add esp,12
	popad
%endmacro

%macro is_op 0
	cmp byte[buffer], 'q'
	je quit
	cmp byte[buffer], '+'
	je plus
	cmp byte[buffer], 'p'
	je pop_and_print
	cmp byte[buffer], 'd'
	je duplicate
	cmp byte[buffer], '&'
	je and_func
	cmp byte[buffer], '|'
	je or_func
	cmp byte[buffer], 'n'
	je dig_num
%endmacro


%macro apply_func 2
	pushad
	push %2
	call %1
	add esp,4
	mov dword[return_pointer],eax
	popad
%endmacro


%macro if_debug 1 
	cmp dword [debug_flag],1
	jne %%end_if
	%1
	%%end_if:
%endmacro


%macro print_debug 2
	pushad
	push %1
	push %2
	push dword [stderr]
	call fprintf
	add esp, 12
	popad
%endmacro


%define link_size 5
%define max_size 1024
%define link_data 0
%define data_part 0
%define next_part 1
	

section .data
	stack_size: dd 5
	debug_flag:dd 0
	quit_flag:dd 0
	stack_counter:dd 0
	first_link_flag:dd 1
	operations_counter:dd 0
	first_number_free:dd 0
	second_number_free:dd 0
	curr_link:dd 0
	first_link:dd 0
	;n_flag:dd 0
	;n_number:dd 0
	carry_flag:dd 0


section .rodata
	string_format: db "%s",0
	int_format: db "%d",0
	oct_format: db "%o",0
	char_format: db "%c",0
	hexa_format: db "%X",0
	prompt_string: db "calc: ",0
	overflow_error:db "Error: Operands Stack Overflow",0
	too_little_argumetns_error:db "Error: Insufficiant Number of Arguments on Stack",0
	new_line:db 10,0
	destination: db "",0
	debug_push_msg: db "Pushed number: %s", 0
	debug_pop_msg: db "Popped number: ", 0
	debug_push_result: db "Pushed result: ",0


section .bss
	buffer: resb max_size
	stack_pointer: resb 4
	main_stack_pointer: resb 4
	return_pointer:resb 4


section .text
	 align 16
	 global main
	extern printf
  	extern fprintf 
  	extern fflush
  	extern malloc 
  	extern calloc 
  	extern free 
  	extern gets 
  	extern getchar 
  	extern fgets 
  	extern stdout
  	extern stdin
  	extern stderr
	extern strcat


main:
	push ebp
	mov ebp, esp
	mov ebx, dword [ebp+8]	; ARGC arg
	mov ecx, dword [ebp+12]	; ptr to argv

	mov edi, 1
	loop_over_argv:
	cmp edi, ebx
	je loop_over_argv_end
	; argv[i] = *(argv + (i * 4))
	mov edx, edi
	shl edx, 2
	add edx, ecx
	mov edx, dword [edx] ; edx = argv[i]
	; argv[i][0] == '-'
	cmp byte [edx], '-'
	je debug_arg

	; Handle stack size
	pushad
	push edx
	call hex_ascii_to_int
	add esp, 4
	mov dword [stack_size], eax
	popad
	jmp loop_over_argv_next

	; Handle "-d"
	debug_arg:
	mov dword [debug_flag], 1

	loop_over_argv_next:
	inc edi
	jmp loop_over_argv
	
	loop_over_argv_end:
	push 4
	push dword [stack_size]
	call calloc
	add esp, 8

	; eax = address of stack
	mov dword [stack_pointer], eax
	mov dword [main_stack_pointer], eax

	call my_calc

	xor edx,edx
	mov edx, dword [operations_counter]
	print stdout,hexa_format,edx
	print stdout,string_format,new_line
	mov esp,ebp
	pop ebp
	ret

my_calc:		
	push ebp
    	mov ebp, esp
	
	my_calc_loop:
		cmp dword[quit_flag],1
		je .end


		print  stdout, string_format, prompt_string
		read_input
		is_op
		jmp add_number					;adding the input number to the stack	
		jmp my_calc_loop


	.end:	
		pop ebp
		ret

	
add_number:
	xor ebx,ebx
	mov ebx,dword[stack_counter]
	cmp ebx,dword[stack_size]
	jl .add

	print stderr,string_format,overflow_error
	print stderr,string_format,new_line
	jmp my_calc_loop
	
	.add:
		xor ebx,ebx
		mov ebx,buffer	;moving the input to ebx
		if_debug{print_debug ebx,debug_push_msg}
			
	.loop:
		cmp byte[ebx],10
		je .end
		push ebx
		push link_size
		call malloc
		add esp,4
		pop ebx
		movzx ecx,byte[ebx]
		sub ecx, 48                             ; edx <- real value of curr char with zero padding
        	cmp ecx,9
		jle .midle 
		sub ecx,7
	.midle:	
		mov byte[eax+data_part],cl		;cl is the low byte of ecx, liitle endian inserting
		mov edx,dword[stack_pointer]
		mov edx,dword[edx]	;giva us the adress that the stack is pointing at(first element/zero)
		mov dword[eax+next_part],edx			;assign next link
		mov edx,dword[stack_pointer]
		mov dword[edx],eax	;assign the data in stack meaning updating what the stack is ointing at
		inc ebx
		jmp .loop


	.end:
		add dword[stack_pointer],4				;movint to the next argument in the stack
		inc dword[stack_counter]
		jmp my_calc_loop					
	
		

and_func:
	inc dword[operations_counter]
	cmp dword[stack_counter], 2
	jge .yes_we_can
	print stderr,string_format, too_little_argumetns_error
	print stderr,string_format, new_line
	jmp my_calc_loop


	.yes_we_can:
		push ebp
		mov ebp,esp
		
		xor ebx,ebx
		xor ecx,ecx
		xor edx,edx
		
		mov eax, dword[stack_pointer]
		sub eax,4
		mov ebx,dword[eax]			;getting first argument from the stack AKA pop
		sub eax,4
		mov ecx,dword[eax]			;getting second argument from the stack
		push ebx
		push ecx
		
		call make_and
		add esp,8

	.end:
		dec dword[stack_counter]
		mov esp,ebp
		pop ebp
		jmp my_calc_loop


make_and:	
	push ebp
	mov ebp,esp
	xor edx,edx
	xor eax,eax
	
	mov ebx,[ebp+8]
	mov ecx,[ebp+12]
	mov dword[first_number_free],ebx
	mov dword[second_number_free],ecx
	
	mov dword[curr_link],0
	mov dword[first_link],0
	
	.loop:
		cmp ebx,0
		je .end
		cmp ecx,0
		je .end

		xor edx,edx
		movzx edx, byte[ebx+data_part]
		and dl,byte[ecx+data_part]

			
		apply_func malloc,link_size
		mov eax,dword[return_pointer]
		mov byte[eax+data_part],dl
		cmp dword[curr_link],0
		jne .not_first

		mov dword[first_link],eax

		
	.not_first:
		cmp dword[curr_link],0
		je .prepare
		
		mov edx, dword[curr_link]
		mov dword[edx+next_part],eax
	
	.prepare:
		mov dword[curr_link],eax
		mov dword[eax+next_part],0
		mov ebx, dword[ebx+next_part]
		mov ecx,dword[ecx+next_part]
		jmp .loop

	.end:
		push dword[first_number_free]
		call free_operand
		add esp,4
		push dword[second_number_free]
		call free_operand
		add esp,4

		sub dword[stack_pointer],4
		mov eax,dword[stack_pointer]
		mov dword[eax],0
		sub dword[stack_pointer],4
		mov eax,dword[stack_pointer]
		mov dword[eax],0
		mov edx,dword[first_link]
		mov dword[eax],edx
		

	cmp dword[debug_flag],0
	je .debug_dont_print
	
	print stderr,string_format,debug_push_result

	mov eax,[first_link]
	push eax
	call print_list_debug
	add esp,4

	print stderr,string_format,new_line

	
	.debug_dont_print:
		add dword[stack_pointer],4
		pop ebp
		ret		
		
		
			
or_func:
	inc dword[operations_counter]
	cmp dword[stack_counter], 2
	jge .yes_we_can
	print stderr,string_format, too_little_argumetns_error
	print stderr,string_format, new_line
	jmp my_calc_loop


	.yes_we_can:
		push ebp
		mov ebp,esp
		
		xor ebx,ebx
		xor ecx,ecx
		xor edx,edx
		
		mov eax, dword[stack_pointer]
		sub eax,4
		mov ebx,dword[eax]			;getting first argument from the stack AKA pop
		sub eax,4
		mov ecx,dword[eax]			;getting second argument from the stack
		push ebx
		push ecx
		
		call make_or
		add esp,8

	.end:
		dec dword[stack_counter]
		mov esp,ebp
		pop ebp
		jmp my_calc_loop


make_or:	
	push ebp
	mov ebp,esp
	xor edx,edx
	xor eax,eax
	
	mov ebx,[ebp+8]
	mov ecx,[ebp+12]
	mov dword[first_number_free],ebx
	mov dword[second_number_free],ecx
	
	mov dword[curr_link],0
	mov dword[first_link],0
	
	
	.loop:
		cmp ebx,0
		je .almost1
		
		cmp ecx,0
		je .almost2

		xor edx,edx
		movzx edx, byte[ebx+data_part]

		or dl,byte[ecx+data_part]


	.apply:		
		apply_func malloc,link_size
		mov eax,dword[return_pointer]
		mov byte[eax+data_part],dl
		cmp dword[curr_link],0
		jne .not_first

		mov dword[first_link],eax

		
	.not_first:
		cmp dword[curr_link],0
		je .prepare
		
		mov edx, dword[curr_link]
		mov dword[edx+next_part],eax
	
	.prepare:
		mov dword[curr_link],eax
		mov dword[eax+next_part],0
		cmp ebx,0
		je .check
		mov ebx, dword[ebx+next_part]
	.check:
		cmp ecx,0
		je .loop
		mov ecx,dword[ecx+next_part]
		jmp .loop

	.almost1:
		cmp ecx,0
		je .end
		xor edx,edx
		movzx edx, byte[ecx+data_part]
		or dl,0
		jmp .apply		
		

	.almost2:
		cmp ebx,0
		je .end
		xor edx,edx
		movzx edx, byte[ebx+data_part]
		or dl,0
		jmp .apply	


	.end:
		push dword[first_number_free]
		call free_operand
		add esp,4
		push dword[second_number_free]
		call free_operand
		add esp,4

		sub dword[stack_pointer],4
		mov eax,dword[stack_pointer]
		mov dword[eax],0
		sub dword[stack_pointer],4
		mov eax,dword[stack_pointer]
		mov dword[eax],0
		mov edx,dword[first_link]
		mov dword[eax],edx
		
	

	cmp dword[debug_flag],0
	je .debug_dont_print
	
	print stderr,string_format,debug_push_result

	mov eax,[first_link]
	push eax
	call print_list_debug
	add esp,4

	print stderr,string_format,new_line

	.debug_dont_print:
		add dword[stack_pointer],4
		pop ebp
		ret		


free_operand:
	push ebp
	mov ebp,esp
	mov ecx,dword[ebp+8]
	mov edx,ecx

	
	.free:
		mov ebx,ecx
		mov ecx,[ecx+next_part]
		apply_func free, ebx
		cmp ecx,0
		je .end
		jmp .free
	.end:
		mov edx,0
		mov esp,ebp
		pop ebp
		ret				


pop_and_print:
	inc dword [operations_counter]
	mov eax, dword [stack_pointer]
	mov ebx, dword[main_stack_pointer]
	cmp eax, dword [main_stack_pointer]

	jne .yes_we_can
	print stderr, string_format,too_little_argumetns_error
	print stderr,string_format,new_line
	
	jmp my_calc_loop

	.yes_we_can:
		sub eax, 4			;get the number
		mov eax, dword [eax]		; eax = link* first

		mov dword[first_number_free],eax	
	
		cmp dword[debug_flag],0
		je .print_not_debug_print

		print stderr,string_format,debug_pop_msg		
		push eax
		call print_list
		add esp, 4
		print stdout,string_format,new_line				
		

	.print_not_debug_print:
		push eax
		call print_list
		add esp, 4

		print stdout,string_format,new_line		

	.end:
		push dword[first_number_free]
		call free_operand
		add esp,4

		sub dword [stack_pointer], 4
		mov eax, dword [stack_pointer]
		mov dword [eax], 0
		dec dword[stack_counter]
		jmp my_calc_loop


print_list:				;printing the number in the right order
	push ebp
	mov ebp, esp

	mov eax, dword [ebp+8]
	cmp eax, 0
	je .return

	push eax
	push dword [eax+next_part];calling a recursive call and that way the first link to get print is the last. 
	call print_list
	add esp, 4

	pop eax

	movzx ebx, byte [eax+data_part]
	add ebx,48
	cmp ebx,'9'
	jle .mid
	add ebx,7
	.mid:
		print stdout,char_format,ebx	

	.return:
		pop ebp
		ret


quit:
	push ebp
	mov ebp,esp
	
	.loop:
		cmp dword[stack_counter],0
		je .end
		
		sub dword[stack_pointer],4
		mov eax,dword[stack_pointer]
		mov eax,dword[eax]
		
		push eax
		call free_operand
		
		add esp,4
		
		dec dword[stack_counter]
		jmp .loop


	.end:
		mov eax,[main_stack_pointer]
		push eax
		call free
		add esp,4
		mov dword[quit_flag],1
		mov esp,ebp
		pop ebp
		jmp my_calc_loop


duplicate:
	inc dword [operations_counter]
	
	cmp dword[stack_counter],1
	jge .overflow_check
	print stderr,string_format, too_little_argumetns_error
	print stderr,string_format, new_line

	jmp my_calc_loop

	.overflow_check:
		xor ebx,ebx
		mov ebx,dword[stack_counter]
		cmp ebx,dword[stack_size]
		jl .yes_we_can
		print stderr,string_format,overflow_error
		jmp my_calc_loop
	
	.yes_we_can:
		push ebp
		mov ebp,esp

		xor ebx,ebx
		xor edx,edx
		
		mov eax,dword[stack_pointer]
		sub eax,4
		mov ebx,dword[eax]
		push ebx
		
		call make_duplicate
		add esp,4
	.return:
		inc dword[stack_counter]
		mov esp,ebp
		pop ebp
		jmp my_calc_loop

make_duplicate:
	push ebp
	mov ebp,esp
	xor edx,edx
	xor eax,eax
	
	mov ebx,[ebp+8]			;get the first number in the stack
	mov dword[curr_link],0
	mov dword[first_link],0
	
	.loop:
		cmp ebx,0		;checking if at the last link
		je .end

		xor edx,edx
		movzx edx,byte[ebx+data_part]
		xor eax,eax
		apply_func malloc,link_size
		mov eax,dword[return_pointer]
		mov byte[eax+data_part],dl
		cmp dword[curr_link],0
		jne .move_on		
		mov dword[first_link],eax
		
	.move_on:
		cmp dword[curr_link],0
		je .dont_att
		mov edx,dword[curr_link]
		mov dword[edx+next_part],eax
		
	.dont_att:
		mov dword[eax+next_part],0
		mov dword[curr_link],eax
		mov ebx,dword[ebx+next_part]
		jmp .loop
	.end:
		mov eax,dword[stack_pointer]
		mov edx,dword[first_link]
		mov dword[eax],edx
		
		cmp dword[debug_flag],0
		je .debug_dont_print
		print stderr,string_format,debug_push_result
		mov eax,[first_link]
		push eax
		call print_list_debug
		add esp,4
		print stderr,string_format,new_line
		
	.debug_dont_print:
		add dword[stack_pointer],4
		pop ebp
		ret	 		
				

plus:
	inc dword[operations_counter]
	cmp dword[stack_counter],2
	jge .yes_we_can
	
	print stderr,string_format, too_little_argumetns_error
	print stderr,string_format, new_line

	jmp my_calc_loop

	.yes_we_can:
		xor ebx,ebx
		xor ecx,ecx

		mov eax,dword[stack_pointer]
		sub eax,4
		mov ebx,dword[eax]	;first argument
		sub eax,4
		mov ecx,dword[eax]	;second argument
		push ebx
		push ecx
	
		call make_plus
		add esp,8
		
		.end:
			dec dword[stack_counter]
			jmp my_calc_loop

make_plus:
	push ebp
	mov ebp,esp
	xor eax,eax
	
	mov ebx,[ebp+8]		;take first argument
	mov ecx,[ebp+12]	;take secong argument
	
	mov dword[first_number_free],ebx
	mov dword[second_number_free],ecx

	mov dword[carry_flag],0
	mov dword[curr_link],0
	mov dword[first_link],0
	
	.loop:
		cmp ebx,0
		je .first_null

		cmp ecx,0
		je .second_null

		movzx edx,byte[ebx+data_part]
		add dl,byte[ecx+data_part]
		add edx,dword[carry_flag]
		mov dword[carry_flag],16
		and dword[carry_flag],edx
		shr byte[carry_flag],4;
		and edx,15;
		
	apply_func malloc, link_size
	mov eax, dword [return_pointer]
	mov byte [eax+data_part], dl

	cmp dword[curr_link],0
	jne .move_on

	mov dword[first_link],eax

	.move_on:
	cmp dword[curr_link],0
	je .dont_att

	mov edx,dword[curr_link]
	mov dword[edx+next_part],eax

	.dont_att:
	mov dword[curr_link],eax

	mov dword[eax+next_part],0

	mov ebx,dword[ebx+next_part]
	mov ecx,dword[ecx+next_part]

	jmp .loop

	.first_null:
	cmp ecx,0
	je .both_null
	
	movzx edx, byte[ecx+data_part]
	add edx, dword[carry_flag]
	mov dword[carry_flag],16
	and dword[carry_flag],edx
	shr byte[carry_flag],4

	and edx,15

	apply_func malloc, link_size
	mov eax, dword [return_pointer]
	mov byte [eax+data_part], dl

	mov edx,dword[curr_link]
	mov dword[edx+next_part],eax
	mov dword[eax+next_part],0
	mov dword[curr_link],eax

	mov ecx,dword[ecx+next_part]

	jmp .first_null

	.second_null:
	cmp ebx,0
	je .both_null


	movzx edx, byte[ebx+data_part]
	add edx, dword[carry_flag]
	mov dword[carry_flag],16
	and dword[carry_flag],edx
	shr byte[carry_flag],4

	and edx,15

	apply_func malloc, link_size
	mov eax, dword [return_pointer]
	mov byte [eax+data_part], dl

	mov edx,dword[curr_link]
	mov dword[edx+next_part],eax
	mov dword[eax+next_part],0
	mov dword[curr_link],eax

	mov ebx,dword[ebx+next_part]

	jmp .second_null

	.both_null:
	cmp dword[carry_flag],0
	je .end
	apply_func malloc, link_size
	mov eax, dword [return_pointer]
	mov byte [eax+data_part], 1
	mov dword [eax+next_part],0
	mov edx, dword[curr_link]
	mov dword[edx+next_part],eax

	.end:
	push dword[first_number_free]
	call free_operand
	add esp,4

	push dword[second_number_free]
	call free_operand
	add esp,4

	sub dword[stack_pointer],4
	mov eax,dword[stack_pointer]
	mov dword[eax],0		
	sub dword[stack_pointer],4
	mov eax,dword[stack_pointer]
	mov dword[eax],0		
	mov edx, dword[first_link]
	mov dword[eax],edx

	cmp dword[debug_flag],0
	je .debug_dont_print

	print stderr,string_format,debug_push_result	

	mov eax,[first_link]
	push eax
	call print_list_debug
	add esp,4

	print stderr,string_format,new_line

	.debug_dont_print:
	add dword[stack_pointer],4
	pop ebp
	ret


dig_num:
	inc dword[operations_counter]
	cmp dword[stack_counter],1
	jge .yes_we_can
	
	print stderr,string_format, too_little_argumetns_error
	print stderr,string_format, new_line

	jmp my_calc_loop

	.yes_we_can:
		mov ebx, dword [stack_pointer]
		sub dword [stack_pointer], 4
		sub ebx, 4
		mov ebx,dword[ebx]	
		mov dword [first_number_free], ebx
		push ebx
		call count_digits
		add esp, 4
		; eax = number of digits
		mov edx, eax
		mov ecx, 0

		mov ebx, edx
		and ebx, 0x00000F00
		shr ebx, 8

		cmp ebx, 0
		je .second_dig
		apply_func malloc,link_size
		mov eax,dword[return_pointer]		
		mov byte [eax], bl
		mov dword [eax + 1], ecx
		mov ecx, eax

	.second_dig:
		mov ebx, edx
		and ebx, 0x000000F0
		shr ebx, 4

		cmp ebx, 0
		je .third_dig
	
		apply_func malloc,link_size
		mov eax,dword[return_pointer]			
		mov byte [eax], bl
		mov dword [eax + 1], ecx
		mov ecx, eax

	.third_dig:
		mov ebx, edx
		and ebx, 0x0000000F
		shr ebx, 0

		apply_func malloc,link_size
		mov eax,dword[return_pointer]		
		mov byte [eax], bl
		mov dword [eax + 1], ecx
		mov ecx, eax
		mov dword[first_link],ecx
	
		mov ebx, dword [stack_pointer]
		mov dword [ebx], ecx
		add dword [stack_pointer], 4 

		cmp dword[debug_flag],0
		je .dont_print

		print stderr,string_format,debug_push_result

		mov eax,[first_link]
		push eax
		call print_list_debug
		add esp,4
		
		print stderr,string_format,new_line

	.dont_print:
		push dword [first_number_free]
		call free_operand
		add esp, 4

		jmp my_calc_loop
	

count_digits:
	push ebp
	mov ebp, esp

	mov ebx, dword [ebp + 8]
	mov eax, 0

	.loop:	
	cmp ebx, 0
	je .loop_end
	inc eax
	mov ebx, dword [ebx + next_part]
	jmp .loop
	
.loop_end:
		pop ebp
		ret

			
print_list_debug:
	push ebp
	mov ebp, esp

	mov eax, dword [ebp+8]
	cmp eax, 0
	je .return

	push eax

	push dword [eax+next_part]
	call print_list_debug
	add esp, 4

	pop eax

	movzx ebx, byte [eax+data_part]

	push ebx
	push int_format
	push dword [stderr]
	call fprintf
	add esp,12

	.return:
	pop ebp
	ret

; int hex_ascii_to_int(char* str)
hex_ascii_to_int:
	push ebp
	mov ebp, esp

	mov eax, 0
	mov ebx, dword [ebp + 8]

	; while (str[i] != '\0')
	.loop:
	cmp byte [ebx], 0
	je .return
	movzx ecx, byte [ebx]
	cmp cl, '9'
	jg .hex_letter

	; Handle digit
	sub cl, '0'
	jmp .cont

	; Handle letter
	.hex_letter: 
	sub cl, 'A'
	add cl, 10

	.cont:
	shl eax, 4
	add eax, ecx
	inc ebx
	jmp .loop

	.return:
	pop ebp
	ret
