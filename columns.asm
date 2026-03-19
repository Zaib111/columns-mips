################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
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
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
# Color literals for ease of use
RED:
    .word 0xff0000
GREEN:
    .word 0x00ff00
BLUE:
    .word 0x0000ff
YELLOW:
    .word 0xffff00
PURPLE:
    .word 0xff00ff
CYAN:
    .word 0x00ffff
WHITE:
    .word 0xffffff
# Constant Data

.eqv HEIGHT 16
.eqv WIDTH 8

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    jal paint_border
    j Exit
    # Initialize the game

paint_border:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a0, ADDR_DSPL
    addi $a0, $a0, 264
    li $a1, HEIGHT
    lw $a2, WHITE
    # draw left border
    jal draw_vertical_line
    # draw right border
    lw $a0, ADDR_DSPL
    addi $a0, $a0, 264
    # set right endpoint
    addi $t0, $zero, WIDTH
    addi $t1, $zero, 4
    mult $t0, $t1
    mflo $t0
    add $a0, $a0, $t0
    jal draw_vertical_line
    # draw top border
    lw $a0, ADDR_DSPL
    addi $a0, $a0, 264
    li $a1, WIDTH
    jal draw_horizontal_line
    # draw bottom border
    lw $a0, ADDR_DSPL
    addi $a0, $a0, 264
    addi $t0, $zero, HEIGHT
    addi $t1, $zero, 128
    mult $t0, $t1
    mflo $t0
    add $a0, $a0, $t0
    addi $a0, $a0, -128
    jal draw_horizontal_line
    
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
    
# game_loop:
    # # 1a. Check if key has been pressed
    # # 1b. Check which key has been pressed
    # # 2a. Check for collisions
	# # 2b. Update locations (capsules)
	# # 3. Draw the screen
	# # 4. Sleep

    # # 5. Go back to Step 1
    # j game_loop

Exit:
    li $v0, 10 # terminate the program gracefully
    syscall