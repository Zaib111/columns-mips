




#########################################
# left to right detection
# assume that the block provided is a whole columns
.data
.eqv WIDTH 8
.eqv HEIGHT 16
.text

######

# convert x and y board position to address

# a0: x - pos 
# a1: y pos
# a2: board data address
# return v0: point address

convert_board_coordinates_to_address:
    add $t0, $zero, $a0
    add $t1, $zero, $a1
    add $t2, $zero, $a2
    sll $t0, $t0, 2
    sll $t1, $t1, 7
    add $t2, $t2, $t0
    add $t2, $t2, $t1
    move $v0, $t2
    jr $ra

######################################
#a0: column data address
#a1: left / right = 0 / 1 
#a2: board data address
# return $v0: 1/0 for success / failure
can_move_column_left_or_right:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $a0, 8($sp)
    sw $a1, 4($sp)
    sw $a2, 0($sp)
    add $t0, $zero, $zero
    move $t0, $a1
    move $a1, $a2
    beq $t0, $zero, can_move_column_left
    j can_move_column_right
    
    
# a0: column data address
# a1: board data address
can_move_column_left:
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    addi $t2, $t0, -1
    beq $t2, $zero, invalid_move
    move $a2, $a1
    move $a0, $t2
    move $a1, $t1
    jal convert_board_coordinates_to_address
    move $t2, $v0
    lw $t6, 0($t2)
    bne $t6, $zero, invalid_move
    lw $t6, 128($t2)
    bne $t6, $zero, invalid_move
    lw $t6, 256($t2)
    bne $t6, $zero, invalid_move
    li $v0, 1
    j return_check_move_to_caller

can_move_column_right:
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    addi $t0, $t0, 1
    li $t2, WIDTH
    beq $t0, $t2, invalid_move
    move $a2, $a1
    move $a0, $t0
    move $a1, $t1
    jal convert_board_coordinates_to_address
    move $t2, $v0
    lw $t6, 0($t2)
    bne $t6, $zero, invalid_move
    lw $t6, 128($t2)
    bne $t6, $zero, invalid_move
    lw $t6, 256($t2)
    bne $t6, $zero, invalid_move
    li $v0, 1
    j return_check_move_to_caller

return_check_move_to_caller:
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

invalid_move:
    li $v0, 0
    j return_check_move_to_caller

########################################
# falling down detection


# a0: columdn data address
# a1: board address
# return $v0: 0 / 1 if there is a block underneath to make it stop or out of bounds
check_column_stop_falling:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    lw $t0, 0($a0) 
    lw $t1, 4($a0) 
    
    # check for out of bounds / at bottom
    li $t2, HEIGHT
    addi $t1, $t1, 3 # bottom position
    beq $t1, $t2, is_not_valid_to_fall
    # check for block underneath
    move $t2, $a1
    move $a0, $t0
    move $a1, $t1
    move $a2, $t2
    jal convert_board_coordinates_to_address
    move $t0, $v0
    lw $t1, 0($t0)
    beq $t1, $zero, is_valid_to_fall
    j is_not_valid_to_fall
    

is_valid_to_fall:
    li $v0, 1
    j clean_up_falling_column
    
is_not_valid_to_fall:
    li $v0, 0
    j clean_up_falling_column

clean_up_falling_column:
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    jr $ra
# check for y spot 3 down
########################################
# clearing detection



########################################
# clear block algorithm