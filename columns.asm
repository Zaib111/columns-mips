################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Victor Li, 1010863978
# Student 2: Shahmeer Khan, 1011049410
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
    .word 0x10008108
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
##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
	la $a0, ACTIVE_COLUMN
	jal generate_drop_column
    j game_loop
    j Exit
    # Initialize the game

##############################################################################
# Border Functions 
##############################################################################
paint_border:
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
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# t6: row counter
paint_background:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $t6, $zero, $zero # row counter
paint_bg_row_loop:
    beq $t6, HEIGHT, end_paint_background
    addi $t7, $zero, 128
    mult $t7, $t6
    mflo $t7
    lw $a0, ADDR_COLUMNS # intializing first argument for starting point (beginning of row)
    add $a0, $a0, $t7
    addi $a0, $a0, 4 # skip left border pixel
    li $a1, WIDTH # setting second argument to width
    li $a2, 0x000000 # setting third argument to black
    jal draw_horizontal_line
    addi $t6, $t6, 1
    j paint_bg_row_loop
end_paint_background:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
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
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $a0, 0($sp)
    jal generate_random_color
    add $s0, $v0, $zero
    jal generate_random_color
    add $s1, $v0, $zero
    jal generate_random_color
    add $s2, $v0, $zero
    
    lw $a0, 0($sp)
    sw $s0, 8($a0)
    sw $s1, 12($a0)
    sw $s2, 16($a0)
    # initialize to default position 
    addi $t3, $zero, WIDTH
    srl $t3, $t3, 2
    sw $t3, 0($a0)
    addi $t5, $zero, 1
    sw $t5, 4($a0)
    
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

#a0: column data address
#a1: pointer address for top left corner of box
draw_drop_column:
    lw $t0, 0($a1)
    lw $t1, 0($a0) # xpos
    lw $t2, 4($a0) # ypos
    sll $t1, $t1, 2
    # li $t3, 4
    # mult $t1, $t3
    # mflo $t1
    # li $t3, 128
    # mult $t2, $t3
    # mflo $t2
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
    
    
game_loop:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD
    lw $t8, 0($t0)
    # 1b. Check which key has been pressed
    beq $t8, 1, keyboard_input
    j no_key
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep
    # 5. Go back to Step 1

keyboard_input:
    # check which key was pressed
    lw $t2, 4($t0)
    beq $t2, 0x61, move_left  # 'a'
    beq $t2, 0x64, move_right # 'd'
    beq $t2, 0x73, move_down  # 's'
    beq $t2, 0x77, shuffle    # 'w'
    beq $t2, 0x71, Exit       # 'q'
    j no_key                  # also ignore unknown key

move_left:
    lw $t1, ACTIVE_COLUMN # load x value
    addi $t1, $t1, -1 # subtract 1 from x
    sw $t1, ACTIVE_COLUMN # update x value
    j no_key

move_right:
    lw $t1, ACTIVE_COLUMN # load x value
    addi $t1, $t1, 1 # add 1 to x
    sw $t1, ACTIVE_COLUMN # update x value
    j no_key

move_down:
    lw $t1, ACTIVE_COLUMN + 4 # load y value
    addi $t1, $t1, 1 # add 1 to y
    sw $t1, ACTIVE_COLUMN + 4 # update y value
    j no_key

shuffle:
    lw $t1, ACTIVE_COLUMN + 8 # load top colour
    lw $t2, ACTIVE_COLUMN + 12 # load middle colour
    lw $t3, ACTIVE_COLUMN + 16 # load bottom colour
    # swapping:
    sw $t1, ACTIVE_COLUMN + 12 
    sw $t2, ACTIVE_COLUMN + 16
    sw $t3, ACTIVE_COLUMN + 8
    
    j no_key
    
no_key:
    jal paint_background # wipe screen
	jal paint_border # redraw borders
	la $a0, ACTIVE_COLUMN
	la $a1, ADDR_COLUMNS
	jal draw_drop_column # draw column at new position
	li $v0, 32
	li $a0, 16
	syscall
	j game_loop
	
Exit:
    li $v0, 10 # terminate the program gracefully
    syscall