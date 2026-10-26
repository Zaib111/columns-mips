################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Victor Li
# Student 2: Shahmeer Khan
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
ADDR_COLUMNS:
    .word 0x100084a8
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
# Color literals for ease of use
BLOCK_COLORS:
    .word 0xff0000    # Index 0: RED
    .word 0x00ff00    # Index 1: GREEN
    .word 0x0000ff    # Index 2: BLUE
    .word 0xffff00    # Index 3: YELLOW
    .word 0xff00ff    # Index 4: PURPLE
    .word 0x00ffff    # Index 5: CYAN
WHITE:
    .word 0xffffff
GRAVITY_COUNTER:
    .word 0
# Gravity Threshold
GRAVITY_THRESHOLD:
    .word 60 
# Time counter to increase gravity
TIME_COUNTER:
    .word 0
MINIMUM_GRAVITY_THRESHOLD:
    .word 10
menu_msg:
    .asciiz "Select difficulty:\n1. Easy\n2. Medium\n3. Hard\n"
# Queue of next 5 columns (each has 3 colors = 3 words)
.align 2
NEXT_COLUMNS:
    .space 60    # 5 columns * 3 colors * 4 bytes
NEXT_COLUMN_COUNT:
    .word 5      # how many are queued (always keep at 5)
# Constant Data

.eqv HEIGHT 16
.eqv WIDTH 8

##############################################################################
# Mutable Data
##############################################################################
.align 2
ACTIVE_COLUMN:
    .word 0x0 # X Position
    .word 0x0 # Y Position
    .word 0xffffff # Top color
    .word 0xffffff # middle color
    .word 0xffffff # bottom color
ACTIVE_GAME_SPACE:
    .space 512
DELETE_SPACES_MASK:
    .space 128
##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # print message to console
    li $v0, 4          
    la $a0, menu_msg
    syscall
    
    # read a character
    li $v0, 12        
    syscall
    
    beq $v0, 0x31, set_easy
    beq $v0, 0x32, set_medium
    beq $v0, 0x33, set_hard
    j set_medium
    
#############################################################################
# Helper Functions
#############################################################################
    
set_easy:
   li $t0, 120
   sw $t0, GRAVITY_THRESHOLD
   j start_game
   
set_medium:
    li $t0, 60
    sw $t0, GRAVITY_THRESHOLD
    j start_game

set_hard:
    li $t0, 30
    sw $t0, GRAVITY_THRESHOLD
    j start_game
    
# Initialize the game
start_game: 
    jal initialize_game_space
	la $a0, ACTIVE_COLUMN
	jal init_queue
	jal generate_drop_column
    j game_loop
    j Exit

# intialize column queue with random colours
init_queue:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, NEXT_COLUMNS
    li $t1, 0
init_queue_loop:
    beq $t1, 15, end_init_queue_loop
    addi $sp, $sp, -8
    
    sw $t0, 0($sp)          # save base address
    sw $t1, 4($sp)          # save counter
    jal generate_random_color
    lw $t0, 0($sp)          
    lw $t1, 4($sp)
    addi $sp, $sp, 8
    
    sw $v0, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j init_queue_loop
end_init_queue_loop:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draws the 5 upcoming columns in a preview panel to the right of the game field
draw_preview_panel:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    la $t0, NEXT_COLUMNS    # start of queue
    li $t1, 0               # entry counter (0-4)
    
    # panel starts at ADDR_COLUMNS + 12 units right (48 bytes) + 1 unit up (-128 bytes)
    lw $t9, ADDR_COLUMNS
    addi $t9, $t9, 48       # skip 9 units right
    addi $t9, $t9, -128      # 1 unit up

draw_preview_loop:
    beq $t1, 5, end_draw_preview_loop
    
    # each entry takes 4 rows (3 gems + 1 gap)
    li $t2, 4
    mul $t2, $t1, $t2       # entry offset in rows
    li $t3, 128             # bytes per row
    mul $t2, $t2, $t3       # byte offset
    add $t2, $t9, $t2       # display addr for this entry's top gem
    
    # load 3 colors for this entry
    li $t3, 12              # 3 words * 4 bytes per entry
    mul $t3, $t1, $t3
    add $t4, $t0, $t3
    lw $t5, 0($t4)          # top color
    lw $t6, 4($t4)          # mid color
    lw $t7, 8($t4)          # bottom color
    
    # draw 3 gems vertically
    sw $t5, 0($t2)
    sw $t6, 128($t2)
    sw $t7, 256($t2)
    
    # gap row
    sw $zero, 384($t2)
    
    addi $t1, $t1, 1
    j draw_preview_loop

end_draw_preview_loop:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

#a1: x-pos
#a2: y-pos
convert_board_coordinates_to_display_address:
    move $t0, $a0
    move $t1, $a1
    lw $t2, ADDR_COLUMNS
    sll $t0, $t0, 2
    sll $t1, $t1, 7
    add $t2, $t2, $t0
    add $t2, $t2, $t1
    move $v0, $t2
    jr $ra

convert_board_coordinates_to_gamespace_address:
    la $t0, ACTIVE_GAME_SPACE
    move $t1, $a0
    move $t2, $a1
    sll $t1, $t1, 2 # x4
    sll $t2, $t2, 5 # x32
    add $t0, $t0, $t1
    add $t0, $t0, $t2
    move $v0, $t0
    jr $ra
    
convert_board_coordinates_to_mask_address:
    la $t0, DELETE_SPACES_MASK
    move $t1, $a0
    move $t2, $a1
    sll $t2, $t2, 3 # x8
    add $t0, $t0, $t1
    add $t0, $t0, $t2
    move $v0, $t0
    jr $ra
##############################################################################
# Border Functions 
##############################################################################
initialize_game_space:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # draw left border
    lw $a0, ADDR_COLUMNS
    li $a1, HEIGHT
    lw $a2, WHITE
    jal draw_vertical_line
    
    # draw right border
    lw $a0, ADDR_COLUMNS
    li $a1, HEIGHT
    lw $a2, WHITE
    addi $t0, $zero, WIDTH
    sll $t0, $t0, 2
    add $a0, $a0, $t0
    jal draw_vertical_line
    
    # draw top border
    lw $a0, ADDR_COLUMNS
    li $a1, WIDTH
    lw $a2, WHITE
    jal draw_horizontal_line
    
    # draw bottom border
    lw $a0, ADDR_COLUMNS
    li $a1, WIDTH
    lw $a2, WHITE
    addi $t0, $zero, HEIGHT
    addi $t0, $t0, -1
    sll $t0, $t0, 7
    add $a0, $a0, $t0
    jal draw_horizontal_line
    # black out rest of space
    jal initialize_to_black
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
initialize_to_black:
    la $t0, ACTIVE_GAME_SPACE   
    li $t1, 0                   
    li $t2, 128                 
    li $t3, 0x000000   

black_loop:
    beq $t1, $t2, end_black     
    sll $t4, $t1, 2             
    add $t5, $t0, $t4           
    sw $t3, 0($t5)              
    addi $t1, $t1, 1            
    j black_loop
end_black:
    jr $ra
    
# a0: game space address
# a1: start point to display columns
draw_game_space:
    addi $sp, $sp, -20
    li $s0, 1
    li $s1, 1
    li $s2, WIDTH
    li $s3, HEIGHT
    addi $s3, $s3, -1 #off by one
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    j outer_draw_game_space_loop
    outer_draw_game_space_loop:
        li $s0, 1
        sw $s0, 4($sp)
        lw $s1, 8($sp)
        lw $s3, 16($sp)
        beq $s1, $s3, exit_outer_draw_game_space_loop
        j inner_draw_game_space_loop
        inner_draw_game_space_loop:
            lw $s0, 4($sp)
            lw $s2, 12($sp)
            beq $s0, $s2, exit_inner_draw_game_space_loop
            move $a0, $s0
            move $a1, $s1
            jal convert_board_coordinates_to_gamespace_address
            move $t6, $v0
            jal convert_board_coordinates_to_display_address
            move $t7, $v0
            lw $t8, 0($t6)
            sw $t8, 0($t7)
            lw $s0, 4($sp)
            addi $s0, $s0, 1
            sw $s0, 4($sp)
            j inner_draw_game_space_loop
        exit_inner_draw_game_space_loop:
            lw $s1, 8($sp)
            addi $s1, $s1, 1
            sw $s1, 8($sp)
            j outer_draw_game_space_loop
    exit_outer_draw_game_space_loop:
        lw $ra, 0($sp)
        addi $sp, $sp, 20
        jr $ra

# $a0: starting pixel
# $a1: height
# $a2: color
draw_vertical_line:
    add $t0, $zero, $zero 
draw_vertical_line_loop:
    beq $t0, $a1, end_draw_vertical_line
    sw $a2, 0($a0)
    addi $a0, $a0, 128
    addi $t0, $t0, 1
    j draw_vertical_line_loop
end_draw_vertical_line:
    jr $ra

# $a0: starting pixel
# $a1: width
# $a2: color
draw_horizontal_line:
    add $t0, $zero, $zero
draw_horizontal_line_loop:
    beq $t0, $a1, end_draw_horizontal_line
    sw $a2, 0($a0)
    addi $a0, $a0, 4
    addi $t0, $t0, 1
    j draw_horizontal_line_loop
end_draw_horizontal_line:
    jr $ra

##############################################################################
# Controllable Column Function 
############################################################################## 
# randomize color
# generate a number 0-6, then get value from base_colors index and return in $v0
generate_random_color:
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    sll $t0, $a0, 2
    la $t1, BLOCK_COLORS
    add $t1, $t1, $t0
    lw $v0, 0($t1)
    jr $ra

# a0: column data address
# store base column data in ACTIVE_COLUMN
generate_drop_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # pop front of queue into column colours
    la $t0, NEXT_COLUMNS
    la $t1, ACTIVE_COLUMN
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)
    
    sw $t2, 8($t1)
    sw $t3, 12($t1)
    sw $t4, 16($t1)
    
    # reset position
    li $t2, 2
    sw $t2, 0($t1)
    li $t2, 1
    sw $t2, 4($t1)
    
    # shift queue left
    addi $t5, $t0, 12 # t5 is the iterator
    addi $t6, $t0, 0
    addi $t7, $t0, 60
shift_loop:
    beq $t5, $t7, end_shift 
    lw $t8, 0($t5)
    sw $t8, 0($t6)
    addi $t5, $t5, 4
    addi $t6, $t6, 4
    j shift_loop
    
end_shift:
    # append to queue
    jal generate_random_color
    la $t0, NEXT_COLUMNS
    sw $v0, 48($t0)
    jal generate_random_color
    la $t0, NEXT_COLUMNS
    sw $v0, 52($t0)
    jal generate_random_color
    la $t0, NEXT_COLUMNS
    sw $v0, 56($t0)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

#a0: column data address
#a1: pointer address for top left corner of box
draw_drop_column:
    lw $t0, ADDR_COLUMNS
    lw $t1, 0($a0) # xpos
    lw $t2, 4($a0) # ypos
    sll $t1, $t1, 2
    sll $t2, $t2, 7
    lw $t3, 8($a0)
    lw $t4, 12($a0)
    lw $t5, 16($a0)
    add $t0, $t0, $t1
    add $t0, $t0, $t2
    
    sw $t3, 0($t0)
    sw $t4, 128($t0)
    sw $t5, 256($t0)
    jr $ra
    
####################################################################
# Collision Detection
####################################################################

######################################
#a0: column data address
#a1: left / right = 0 / 1 
#a2: game space address
# return $v0: 1/0 for success / failure
can_move_column_left_or_right:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $a0, 8($sp)
    sw $a1, 4($sp)
    sw $a2, 0($sp)
    move $t0, $a1
    move $a1, $a2
    beq $t0, $zero, can_move_column_left
    j can_move_column_right
    
    
# a0: column data address
# a1: game space address
can_move_column_left:
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    addi $t2, $t0, -1
    beq $t2, $zero, invalid_move
    addi $a0, $t0, -1
    move $a1, $t1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    addi $a1, $a1, 1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    addi $a1, $a1, 1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    li $v0, 1
    j return_check_move_to_caller

can_move_column_right:
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    addi $t0, $t0, 1
    li $t2, WIDTH
    beq $t0, $t2, invalid_move
    move $a0, $t0
    move $a1, $t1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    addi $a1, $a1, 1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    addi $a1, $a1, 1
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_move
    li $v0, 1
    j return_check_move_to_caller

return_check_move_to_caller:
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

invalid_move:
    li $v0, 0
    j return_check_move_to_caller
    
#a0: column data address
#a1: gamespace data address
#return v0: 1 / 0 depending on success / fail, IF there is empty space underneath the column
can_move_column_down:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    li $t2, HEIGHT
    addi $t2, $t2, -4
    beq $t1, $t2, invalid_drop_down
    move $a0, $t0
    move $a1, $t1
    addi $a1, $a1, 3 # check for the 3rd down from head position
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_drop_down
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 1
    jr $ra
    
invalid_drop_down:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 0
    jr $ra

#a0: column data address
#a1: gamespace data address
#return v0: 1 / 0 depending on success / fail, IF there is empty space underneath the column
is_column_on_top_of_block:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    li $t2, HEIGHT
    addi $t2, $t2, -4
    beq $t1, $t2, invalid_drop_down
    move $a0, $t0
    move $a1, $t1
    addi $a1, $a1, 3 # check for the 3rd down from head position
    jal convert_board_coordinates_to_gamespace_address
    lw $t3, 0($v0)
    bne $t3, $zero, invalid_drop_down
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 1
    jr $ra
###################################################################
# Board modification
###################################################################
# a0: column data address
place_column_in_game_space:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    move $a0, $t0
    move $a1, $t1
    jal convert_board_coordinates_to_gamespace_address
    lw $a0, 4($sp)
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    lw $t3, 8($a0) # top color
    sw $t3, 0($v0)
    addi $t1, $t1, 1
    move $a0, $t0
    move $a1, $t1
    jal convert_board_coordinates_to_gamespace_address
    lw $a0, 4($sp)
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    lw $t3, 12($a0) # top color
    sw $t3, 0($v0)
    addi $t1, $t1, 2
    move $a0, $t0
    move $a1, $t1
    jal convert_board_coordinates_to_gamespace_address
    lw $a0, 4($sp)
    lw $t3, 16($a0)
    sw $t3, 0($v0)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra
    
# a0: game space address  
deletion_algorithm:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
deletion_algorithm_loop:
    la $a0, ACTIVE_GAME_SPACE
    jal mark_delete_bits
    beq $v0, $zero, end_deletion_algorithm
    jal delete_values_from_mask
    la $a0, ACTIVE_GAME_SPACE
    jal apply_board_gravity
    j deletion_algorithm_loop

end_deletion_algorithm:
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

# a0: game space address
apply_board_gravity:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    # loop through all possible spaces, if not empty, check underneath and move if empty space underneath. if more than one bit was moved,
    # do it again until nothing remains.
apply_board_gravity_outer_loop:
    li $s5, 0
    li $s6, 111 # assuming 16 x 8 bits, last row doesnt count / cant be pushed down, last last row is techinically white space
    li $t1, 0
    apply_board_gravity_inner_loop:
        beq $s5, $s6, end_apply_board_gravity_inner_loop
        lw $t2, 4($sp)
        sll $t3, $s6, 2
        add $t4, $t2, $t3
        lw $t5, 0($t4) # current bit
        addi $t7, $s6, 8
        sll $t7, $t7, 2
        add $t8, $t2, $t7
        lw $t6, 0($t8) # bit one row down
        beq $t5, $zero, skip_apply_board_gravity_inner_loop
        bne $t6, $zero, skip_apply_board_gravity_inner_loop
        sw $t5, 0($t8) # move down
        sw $zero, 0($t4) # set current to empty
        addi $s6, $s6, -1
        addi $t1, $t1, 1 # increment count of moved down
        j apply_board_gravity_inner_loop
    skip_apply_board_gravity_inner_loop:
        addi $s6, $s6, -1
        j apply_board_gravity_inner_loop
    end_apply_board_gravity_inner_loop:
        beq $t1, $zero, end_apply_board_gravity_outer_loop
        # at this point, at least one bit has been moved
        j apply_board_gravity_outer_loop
end_apply_board_gravity_outer_loop:
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra


delete_values_from_mask:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, ACTIVE_GAME_SPACE
    la $t1, DELETE_SPACES_MASK
    li $t2, 0                   
    li $t3, 128
    li $t9, 0 # intialize delete indicator to 0
delete_loop:
    beq $t2, $t3, stop_delete
    sll $t4, $t2, 2 # addr for active-game-space since its 4 bytes
    add $t5, $t1, $t2
    lb $t7, 0($t5)
    bne $t7, $zero, delete_bit_from_game_space
    addi $t2, $t2, 1
    j delete_loop
delete_bit_from_game_space:
    add $t6, $t0, $t4
    sw $zero, 0($t6)
    sb $zero, 0($t5)
    li $t9, 1 # tracking if we are deleting
    addi $t2, $t2, 1
    j delete_loop
stop_delete:
    beq $t9, $zero, skip_delete_sound
    # play sound
    li $v0, 31
    li $a0, 60    
    li $a1, 200   
    li $a2, 0     
    li $a3, 100
    syscall
    skip_delete_sound:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra


#a0: game space address
# return $v0: 1 / 0 whether to trigger board gravity and to re evaluate for deletion again
mark_delete_bits:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $zero, 8($sp)
    li $s5, 0
    li $s6, 128
mark_delete_bits_loop:
    beq $s5, $s6, end_mark_delete_bits_loop
    lw $a0, 4($sp)
    li $t6, 8
    div $s5, $t6
    mfhi $a1
    mflo $a2
    sll $t7, $s5, 2
    add $t8, $a0, $t7
    lw $a3, 0($t8)
    jal mark_delete_consecutive_horizontal
    lw $t0, 8($sp)
    add $t0, $t0, $v0
    sw $t0, 8($sp)
    lw $a0, 4($sp)
    li $t6, 8
    div $s5, $t6
    mfhi $a1
    mflo $a2
    sll $t7, $s5, 2
    add $t8, $a0, $t7
    lw $a3, 0($t8)
    jal mark_delete_consecutive_vertical
    lw $t0, 8($sp)
    add $t0, $t0, $v0
    sw $t0, 8($sp)
    lw $a0, 4($sp)
    li $t6, 8
    div $s5, $t6
    mfhi $a1
    mflo $a2
    sll $t7, $s5, 2
    add $t8, $a0, $t7
    lw $a3, 0($t8)
    jal mark_delete_consecutive_right_diagonal
    lw $t0, 8($sp)
    add $t0, $t0, $v0
    sw $t0, 8($sp)
    lw $a0, 4($sp)
    li $t6, 8
    div $s5, $t6
    mfhi $a1
    mflo $a2
    sll $t7, $s5, 2
    add $t8, $a0, $t7
    lw $a3, 0($t8)
    jal mark_delete_consecutive_left_diagonal
    lw $t0, 8($sp)
    add $t0, $t0, $v0
    sw $t0, 8($sp)
    addi $s5, $s5, 1
    j mark_delete_bits_loop
end_mark_delete_bits_loop:
    lw $ra, 0($sp)
    lw $t0, 8($sp)
    sgt $v0, $t0, $zero# more than one bit deleted
    addi $sp, $sp, 12
    jr $ra


#a0: game space address
#a1: root x-pos
#a2: root y-pos
#a3: root color
# count # of matching consecutive in horizontal row. if >= 3, mark for deletion.
# return $v0: # of deleted bits marked
mark_delete_consecutive_horizontal:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    beq $a3, $zero, end_mark_consecutive_horizontal
check_right_horizontal:
    li $s1, 0
    li $t3, WIDTH
    lw $t4, 8($sp)
    addi $t4, $t4, 1
check_right_horizontal_loop:
    beq $t4, $t3, check_left_horizontal
    move $a0, $t4
    lw $a1, 12($sp)
    jal convert_board_coordinates_to_gamespace_address
    lw $t5, 0($v0)
    lw $t6, 16($sp)
    bne $t6, $t5, check_left_horizontal
    addi $s1, $s1, 1
    addi $t4, $t4, 1
    j check_right_horizontal_loop
check_left_horizontal:
    li $s2, 0
    lw $t4, 8($sp)
    addi $t4, $t4, -1
check_left_horizontal_loop:
    beq $t4, $zero, evaluate_delete_consecutive_horizontal
    move $a0, $t4
    lw $a1, 12($sp)
    jal convert_board_coordinates_to_gamespace_address
    lw $t5, 0($v0)
    lw $t6, 16($sp)
    bne $t6, $t5, evaluate_delete_consecutive_horizontal
    addi $s2, $s2, 1
    addi $t4, $t4, -1
    j check_left_horizontal_loop
evaluate_delete_consecutive_horizontal:
    # t1, t2 represent the counts on left and right
    add $s3, $s1, $s2
    li $t5, 1
    sgt $t4, $s3, $t5
    beq $t4, $zero, end_mark_consecutive_horizontal
    # mark the elements
mark_right_consecutive_horizontal_loop:
    beq $s1, $zero, mark_left_consecutive_horizontal_loop
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    add $a0, $a0, $s1
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s1, $s1, -1
    j mark_right_consecutive_horizontal_loop
mark_left_consecutive_horizontal_loop:
    beq $s2, $zero, end_mark_consecutive_horizontal
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    sub $a0, $a0, $s2
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s2, $s2, -1
    j mark_left_consecutive_horizontal_loop
end_mark_consecutive_horizontal:
    li $t5, 1
    sgt $v0, $s3, $t5
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra
    
#a0: game space address
#a1: root x-pos
#a2: root y-pos
#a3: root color
# count # of matching consecutive in vertical column. if >= 3, mark for deletion.
# return $v0: # of deleted bits marked
mark_delete_consecutive_vertical:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    beq $a3, $zero, end_mark_consecutive_vertical
check_up_vertical:
    li $s1, 0
    lw $t4, 12($sp)
    addi $t4, $t4, -1
check_up_vertical_loop:
    beq $t4, $zero, check_down_vertical
    move $a1, $t4
    lw $a0, 8($sp)
    jal convert_board_coordinates_to_gamespace_address
    lw $t5, 0($v0)
    lw $t6, 16($sp)
    bne $t6, $t5, check_down_vertical
    addi $s1, $s1, 1
    addi $t4, $t4, -1
    j check_up_vertical_loop
check_down_vertical:
    li $s2, 0
    li $t3, HEIGHT
    lw $t4, 12($sp)
    addi $t4, $t4, 1
check_down_vertical_loop:
    beq $t4, $t3, evaluate_delete_consecutive_vertical
    move $a1, $t4
    lw $a0, 8($sp)
    jal convert_board_coordinates_to_gamespace_address
    lw $t5, 0($v0)
    lw $t6, 16($sp)
    bne $t6, $t5, evaluate_delete_consecutive_vertical
    addi $s2, $s2, 1
    addi $t4, $t4, 1
    j check_down_vertical_loop
evaluate_delete_consecutive_vertical:
    add $s3, $s1, $s2
    li $t5, 1
    sgt $t4, $s3, $t5
    beq $t4, $zero, end_mark_consecutive_vertical
mark_up_consecutive_vertical_loop:    
    beq $s1, $zero, mark_down_consecutive_vertical_loop
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    sub $a1, $a1, $s1
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s1, $s1, -1
    j mark_up_consecutive_vertical_loop
mark_down_consecutive_vertical_loop:
    beq $s2, $zero, mark_left_consecutive_horizontal_loop
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    add $a1, $a1, $s2
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s2, $s2, -1
    j mark_down_consecutive_vertical_loop
end_mark_consecutive_vertical:
    li $t5, 1
    sgt $v0, $s3, $t5
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra
    
#a0: game space address
#a1: root x-pos
#a2: root y-pos
#a3: root color
# count # of matching consecutive in diagonal going top left to bottom right. if >= 3, mark for deletion.
# return $v0: # of deleted bits marked
mark_delete_consecutive_right_diagonal:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    beq $a3, $zero, end_mark_consecutive_right_diagonal
check_up_left_consecutive_diagonal:
    li $s1, 0
    lw $t4, 8($sp)   # Current X
    lw $t5, 12($sp)  # Current Y
    addi $t4, $t4, -1
    addi $t5, $t5, -1
check_up_left_consecutive_diagonal_loop:
    beq $t4, $zero, check_down_right_consecutive_diagonal
    beq $t5, $zero, check_down_right_consecutive_diagonal
    move $a0, $t4
    move $a1, $t5
    jal convert_board_coordinates_to_gamespace_address
    lw $t7, 0($v0)
    lw $t8, 16($sp)  
    bne $t7, $t8, check_down_right_consecutive_diagonal
    
    addi $s1, $s1, 1
    addi $t4, $t4, -1
    addi $t5, $t5, -1
    j check_up_left_consecutive_diagonal_loop
    
check_down_right_consecutive_diagonal:
    li $s2, 0
    lw $t4, 8($sp)
    lw $t5, 12($sp)
    addi $t4, $t4, 1
    addi $t5, $t5, 1
check_down_right_consecutive_diagonal_loop:
    li $t9, WIDTH
    beq $t4, $t9, evaluate_delete_consecutive_right_diagonal
    li $t9, HEIGHT
    beq $t5, $t9, evaluate_delete_consecutive_right_diagonal
    move $a0, $t4
    move $a1, $t5
    jal convert_board_coordinates_to_gamespace_address
    lw $t7, 0($v0)
    lw $t8, 16($sp)
    bne $t7, $t8, evaluate_delete_consecutive_right_diagonal
    addi $s2, $s2, 1
    addi $t4, $t4, 1
    addi $t5, $t5, 1
    j check_down_right_consecutive_diagonal_loop
    
evaluate_delete_consecutive_right_diagonal:
    add $s3, $s1, $s2
    li $t5, 1
    sgt $t4, $s3, $t5
    beq $t4, $zero, end_mark_consecutive_right_diagonal
mark_up_left_consecutive_diagonal_loop:
    beq $s1, $zero, mark_down_right_consecutive_diagonal_loop
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    sub $a0, $a0, $s1
    sub $a1, $a1, $s1
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s1, $s1, -1
    j mark_up_left_consecutive_diagonal_loop
mark_down_right_consecutive_diagonal_loop:
    beq $s2, $zero, end_mark_consecutive_right_diagonal
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    add $a0, $a0, $s2
    add $a1, $a1, $s2
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s2, $s2, -1
    j mark_down_right_consecutive_diagonal_loop
end_mark_consecutive_right_diagonal:
    li $t5, 1
    sgt $v0, $s3, $t5
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra

#a0: game space address
#a1: root x-pos
#a2: root y-pos
#a3: root color
# count # of matching consecutive in diagonal going bottom left to top right. if >= 3, mark for deletion.
# return $v0: # of deleted bits marked
mark_delete_consecutive_left_diagonal:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $a0, 4($sp)   # Gamespace base
    sw $a1, 8($sp)   # Root X
    sw $a2, 12($sp)  # Root Y
    sw $a3, 16($sp)  # Root Color
    beq $a3, $zero, end_mark_consecutive_left_diagonal
    
check_up_right_consecutive_diagonal:
    li $s1, 0
    lw $t4, 8($sp)   # Current X
    lw $t5, 12($sp)  # Current Y
    addi $t4, $t4, 1
    addi $t5, $t5, -1
check_up_right_consecutive_diagonal_loop:
    li $t9, WIDTH
    beq $t4, $t9, check_down_left_consecutive_diagonal
    beq $t5, $zero, check_down_left_consecutive_diagonal
    move $a0, $t4
    move $a1, $t5
    jal convert_board_coordinates_to_gamespace_address
    lw $t7, 0($v0)
    lw $t8, 16($sp)  
    bne $t7, $t8, check_down_left_consecutive_diagonal
    
    addi $s1, $s1, 1
    addi $t4, $t4, 1
    addi $t5, $t5, -1
    j check_up_right_consecutive_diagonal_loop
    
check_down_left_consecutive_diagonal:
    li $s2, 0
    lw $t4, 8($sp)
    lw $t5, 12($sp)
    addi $t4, $t4, -1
    addi $t5, $t5, 1
check_down_left_consecutive_diagonal_loop:
    li $t9, HEIGHT
    beq $t4, $zero, evaluate_delete_consecutive_left_diagonal
    beq $t5, $t9, evaluate_delete_consecutive_left_diagonal
    move $a0, $t4
    move $a1, $t5
    jal convert_board_coordinates_to_gamespace_address
    lw $t7, 0($v0)
    lw $t8, 16($sp)
    bne $t7, $t8, evaluate_delete_consecutive_left_diagonal
    addi $s2, $s2, 1
    addi $t4, $t4, -1
    addi $t5, $t5, 1
    j check_down_left_consecutive_diagonal_loop
    
evaluate_delete_consecutive_left_diagonal:
    add $s3, $s1, $s2
    li $t5, 1
    sgt $t4, $s3, $t5
    beq $t4, $zero, end_mark_consecutive_right_diagonal
mark_up_right_consecutive_diagonal_loop:
    beq $s1, $zero, mark_down_left_consecutive_diagonal_loop
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    add $a0, $a0, $s1
    sub $a1, $a1, $s1
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s1, $s1, -1
    j mark_up_right_consecutive_diagonal_loop
mark_down_left_consecutive_diagonal_loop:
    beq $s2, $zero, end_mark_consecutive_left_diagonal
    lw $a0, 8($sp)
    lw $a1, 12($sp)
    sub $a0, $a0, $s2
    add $a1, $a1, $s2
    jal convert_board_coordinates_to_mask_address
    li $t7, 1
    sb $t7, 0($v0)
    addi $s2, $s2, -1
    j mark_down_left_consecutive_diagonal_loop
end_mark_consecutive_left_diagonal:
    li $t5, 1
    sgt $v0, $s3, $t5
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra

#a0: game space addresss
check_game_over:
    li $t0, 8
    li $t1, 16
check_game_over_loop:
    beq $t0, $t1, report_no_game_over
    sll $t2, $t0, 2
    add $t3, $a0, $t2
    lw $t4, 0($t3)
    bne $t4, $zero, report_game_over
    addi $t0, $t0, 1
    j check_game_over_loop

report_no_game_over:
    li $v0, 0
    jr $ra
report_game_over:
    li $v0, 1
    jr $ra
##################################################################
# Keyboard Inputs

###################################################################
# a0: keyboard input
# a1: 
keyboard_input:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, ADDR_KBRD
    lw $t8, 0($t0)
    beq $t8, $zero, clean_up_keyboard_input
    # check which key was pressed
    lw $t2, 4($t0)
    beq $t2, 0x61, move_left  # 'a'
    beq $t2, 0x64, move_right # 'd'
    beq $t2, 0x73, move_down  # 's'
    beq $t2, 0x77, shuffle    # 'w'
    beq $t2, 0x70, pause      # 'p'
    beq $t2, 0x71, Exit       # 'q'
    j clean_up_keyboard_input                  # also ignore unknown key

pause:
    # fill entire screen grey for pause message
    lw $a0, ADDR_COLUMNS
    addi $a0, $a0, 132 # skip top border and get inside borders
    li $a1, 7
    li $a2, 0x888888
    li $s0, 0 # counter variable for filling
fill_grey:
    beq $s0, 14, filled_grey # only go till before bottom border
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    jal draw_horizontal_line
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    addi $a0, $a0, 128
    addi $s0, $s0, 1
    j fill_grey
filled_grey:

    # draw left bar
    lw $a0, ADDR_COLUMNS
    addi $a0, $a0, 128    # skip top border
    addi $a0, $a0, 512    # move down 4 rows
    addi $a0, $a0, 12     # x=3
    li $a1, 6             # 6 units tall
    li $a2, 0xffffff
    jal draw_vertical_line
    
    # draw right bar
    lw $a0, ADDR_COLUMNS
    addi $a0, $a0, 128
    addi $a0, $a0, 512
    addi $a0, $a0, 20     # x=5
    li $a1, 6
    li $a2, 0xffffff
    jal draw_vertical_line
    
    # check input again
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, $zero, filled_grey # wait for key press
    lw $t2, 4($t0) # check which key was pressed
    bne $t2, 0x70, filled_grey     # 'p'
    # restore game space
    jal draw_game_space        # redraws settled gems
    j clean_up_keyboard_input
    
move_left:
    la $a0, ACTIVE_COLUMN
    li $a1, 0
    la $a2, ACTIVE_GAME_SPACE
    jal can_move_column_left_or_right
    move $t0, $v0
    beq $t0, $zero, clean_up_keyboard_input
    lw $t1, ACTIVE_COLUMN # load x value
    addi $t1, $t1, -1 # subtract 1 from x
    sw $t1, ACTIVE_COLUMN # update x value
    j clean_up_keyboard_input

move_right:
    la $a0, ACTIVE_COLUMN
    li $a1, 1
    la $a2, ACTIVE_GAME_SPACE
    jal can_move_column_left_or_right
    move $t0, $v0
    beq $t0, $zero, clean_up_keyboard_input
    lw $t1, ACTIVE_COLUMN # load x value
    addi $t1, $t1, 1 # add 1 to x
    sw $t1, ACTIVE_COLUMN # update x value
    j clean_up_keyboard_input
    
move_down:
    la $a0, ACTIVE_COLUMN
    la $a1, ACTIVE_GAME_SPACE
    jal can_move_column_down
    beq $v0, $zero, clean_up_keyboard_input
    lw $t1, ACTIVE_COLUMN + 4 # load y value
    addi $t1, $t1, 1 # add 1 to y
    sw $t1, ACTIVE_COLUMN + 4 # update y value
    j clean_up_keyboard_input

shuffle:
    lw $t1, ACTIVE_COLUMN + 8 # load top colour
    lw $t2, ACTIVE_COLUMN + 12 # load middle colour
    lw $t3, ACTIVE_COLUMN + 16 # load bottom colour
    # swapping:
    sw $t1, ACTIVE_COLUMN + 12 
    sw $t2, ACTIVE_COLUMN + 16
    sw $t3, ACTIVE_COLUMN + 8
    
    # play sound
    li $v0, 31
    li $a0, 72    # high pitch note
    li $a1, 100   # 100ms duration
    li $a2, 0     # instrument
    li $a3, 100   # volume
    syscall
    
    j clean_up_keyboard_input

clean_up_keyboard_input:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

################################################################################
# game loop logic
###############################################################################
	
game_loop:
    # 1a. Check if key has been pressed
    jal keyboard_input
    la $a0, ACTIVE_COLUMN
    la $a1, ACTIVE_GAME_SPACE
    jal is_column_on_top_of_block
    beq $v0, $zero, collision_occured    
    j render_screen
	
collision_occured: 
    # evaluate if head of column is out of bounds : then game over
    la $a0, ACTIVE_COLUMN
    jal place_column_in_game_space
    
    # play drop sound
    li $v0, 31
    li $a0, 40
    li $a1, 100
    li $a2, 0
    li $a3, 100
    syscall
    
	# 2b. Update locations (capsules)
	la $a0, ACTIVE_GAME_SPACE
	jal deletion_algorithm
	# if there is some value still in the top row, then it means game over
	la $a0, ACTIVE_GAME_SPACE
    jal check_game_over
    bne $v0, $zero, game_over
    # delete and clean up board
    la $a0, ACTIVE_COLUMN
    jal generate_drop_column

    j render_screen
    
render_screen:
	# 3. Draw the screen
    jal draw_game_space
	la $a0, ACTIVE_COLUMN
	lw $a1, ADDR_COLUMNS
	jal draw_drop_column # draw column at new position
	jal draw_preview_panel
	# increment gravity counter
	lw  $t1, GRAVITY_COUNTER
	addi $t1, $t1, 1
	sw $t1, GRAVITY_COUNTER
	
	lw $t2, GRAVITY_THRESHOLD
	
	# check if counter == threshold (60) 
	bne $t1, $t2, skip_gravity
	
	# gravity logic
	sw $zero, GRAVITY_COUNTER # reset counter to 0
	lw $t3, ACTIVE_COLUMN + 4
	addi $t3, $t3, 1
	sw $t3, ACTIVE_COLUMN + 4
	
	# increment time counter every second
	lw $t4, TIME_COUNTER
	addi $t4, $t4, 1
	sw $t4, TIME_COUNTER
	
	li $t5, 10
	div $t4, $t5
	mfhi $t5 # get remainder
	bne $t5, $zero, skip_gravity
	
	# check if threshold is >= minimum threshold
	lw $t6, MINIMUM_GRAVITY_THRESHOLD
	beq $t6, $t2, skip_gravity
	addi $t2, $t2, -10
	sw $t2, GRAVITY_THRESHOLD

skip_gravity:
	# 4. Sleep
	li $v0, 32
	li $a0, 16
	syscall
	
	# 5. Go back to Step 1
	j game_loop


game_over:
    # play sound
    li $v0, 31
    li $a0, 60    
    li $a1, 200   
    li $a2, 0     
    li $a3, 100
    syscall
    
    # fill entire screen red for game over message
    lw $a0, ADDR_COLUMNS
    addi $a0, $a0, 132 # skip top border and get inside borders
    li $a1, 7
    li $a2, 0x880000 # red
    li $s0, 0 # counter variable for filling
fill_red:
    beq $s0, 14, draw_x # only go till before bottom border
    addi $sp, $sp, -4
    sw $a0, 0($sp)
    jal draw_horizontal_line
    lw $a0, 0($sp)
    addi $sp, $sp, 4
    addi $a0, $a0, 128
    addi $s0, $s0, 1
    j fill_red

draw_x:
    # Draw the \ diagonal: (x=1,y=5) down to (x=6,y=9)
    # Each step: x += 1 col (4 bytes), y += 1 row (128 bytes)
    lw $t0, ADDR_COLUMNS
    # Starting position: col 1, row 5
    addi $t0, $t0, 4      # col 1
    addi $t0, $t0, 640    # row 5
    li $t1, 0xff4444      # bright red for X
    li $t2, 6             # 6 pixels per diagonal
    li $t3, 0             # counter

draw_backslash_loop:
    beq $t3, $t2, draw_forward_slash
    sw $t1, 0($t0)
    addi $t0, $t0, 4      # next col
    addi $t0, $t0, 128    # next row
    addi $t3, $t3, 1
    j draw_backslash_loop

draw_forward_slash:
    # Draw the / diagonal: (x=6,y=5) down to (x=1,y=9)
    lw $t0, ADDR_COLUMNS
    addi $t0, $t0, 24     # col 6
    addi $t0, $t0, 640    # row 5
    li $t3, 0

draw_slash_loop:
    beq $t3, $t2, restart_or_quit
    sw $t1, 0($t0)
    addi $t0, $t0, -4     # prev col (-1)
    addi $t0, $t0, 128    # next row (+1)
    addi $t3, $t3, 1
    j draw_slash_loop

restart_or_quit:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, $zero, restart_or_quit # wait for key press
    lw $t2, 4($t0) # check which key was pressed
    beq $t2, 0x71, Exit     # 'q'
    bne $t2, 0x72, restart_or_quit # 'r'
    
    # reset game logic to restart game
    jal initialize_game_space
    jal init_queue
    jal generate_drop_column
    # reset variables
    sw $zero, GRAVITY_COUNTER
    li $t0, 60
    sw $t0, GRAVITY_THRESHOLD
    sw $zero, TIME_COUNTER
    j game_loop
    
Exit:
    li $v0, 10 # terminate the program gracefully
    syscall