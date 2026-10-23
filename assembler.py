# ============================================================
# 32-BIT CPU ASSEMBLER - VERSION 1
# ============================================================

# ------------------------------------------------------------
# Register parser
# ------------------------------------------------------------

def register_number(reg):
    reg = reg.upper().strip()

    if not reg.startswith("R"):
        raise ValueError(f"Invalid register: {reg}")

    try:
        number = int(reg[1:])
    except ValueError:
        raise ValueError(f"Invalid register: {reg}")

    if number < 0 or number > 31:
        raise ValueError(f"Register out of range: {reg}")

    return number


# ------------------------------------------------------------
# Utility functions
# ------------------------------------------------------------

def check_16bit(value):
    if value < -32768 or value > 65535:
        raise ValueError(f"Immediate out of 16-bit range: {value}")


def encode_r_type(opcode, rs, rt, rd):
    """
    R-type format:

    [31:26] opcode
    [25:21] rs
    [20:16] rt
    [15:11] rd
    [10:0]  zero
    """

    instruction = (
        (opcode << 26)
        | (rs << 21)
        | (rt << 16)
        | (rd << 11)
    )

    return instruction


def encode_i_type(opcode, rs, rt, immediate):
    """
    I-type format:

    [31:26] opcode
    [25:21] rs
    [20:16] rt
    [15:0]  immediate
    """

    check_16bit(immediate)

    immediate &= 0xFFFF

    instruction = (
        (opcode << 26)
        | (rs << 21)
        | (rt << 16)
        | immediate
    )

    return instruction
def encode_branch(opcode, rs, offset):
    """
    Branch format:

    [31:26] opcode
    [25:21] rs
    [20:16] zero
    [15:0]  branch offset
    """

    check_16bit(offset)

    offset &= 0xFFFF

    instruction = (
        (opcode << 26)
        | (rs << 21)
        | offset
    )

    return instruction
# ------------------------------------------------------------
# Parse memory operand
#
# Example:
#     4(R2)
#
# Returns:
#     immediate = 4
#     register  = R2
# ------------------------------------------------------------

def parse_memory_operand(operand):

    operand = operand.replace(" ", "")

    if "(" not in operand or ")" not in operand:
        raise ValueError(
            "Memory operand must be in the form offset(Rs)"
        )

    try:
        immediate = int(
            operand.split("(")[0],
            0
        )

        reg = operand.split("(")[1].replace(")", "")

    except Exception:
        raise ValueError(
            f"Invalid memory operand: {operand}"
        )

    rs = register_number(reg)

    return immediate, rs

# ------------------------------------------------------------
# Assemble one instruction
# ------------------------------------------------------------

def assemble_instruction(line, labels=None, current_address=0):

    # Remove comments
    line = line.split("#")[0].strip()

    if not line:
        return None

    # Replace commas with spaces
    line = line.replace(",", " ")

    # Split instruction into parts
    parts = line.split()

    mnemonic = parts[0].upper()
    operands = parts[1:]


    # --------------------------------------------------------
    # MOVI
    #
    # MOVI R1, 10
    #
    # opcode = 001111
    # rt     = R1
    # immediate = 10
    # --------------------------------------------------------

    if mnemonic == "MOVI":

        if len(operands) != 2:
            raise ValueError("MOVI syntax: MOVI Rd, immediate")

        rt = register_number(operands[0])
        immediate = int(operands[1], 0)

        opcode = 0b001111

        return encode_i_type(
            opcode,
            0,
            rt,
            immediate
        )


    # --------------------------------------------------------
    # ADD
    #
    # ADD R3, R1, R2
    #
    # opcode = 000000
    # --------------------------------------------------------

    elif mnemonic == "ADD":

        if len(operands) != 3:
            raise ValueError("ADD syntax: ADD Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000000

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # SUB
    # --------------------------------------------------------

    elif mnemonic == "SUB":

        if len(operands) != 3:
            raise ValueError("SUB syntax: SUB Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000001

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # AND
    # --------------------------------------------------------

    elif mnemonic == "AND":

        if len(operands) != 3:
            raise ValueError("AND syntax: AND Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000010

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # OR
    # --------------------------------------------------------

    elif mnemonic == "OR":

        if len(operands) != 3:
            raise ValueError("OR syntax: OR Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000011

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # SLT
    # --------------------------------------------------------

    elif mnemonic == "SLT":

        if len(operands) != 3:
            raise ValueError("SLT syntax: SLT Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000100

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # MUL
    # --------------------------------------------------------

    elif mnemonic == "MUL":

        if len(operands) != 3:
            raise ValueError("MUL syntax: MUL Rd, Rs, Rt")

        rd = register_number(operands[0])
        rs = register_number(operands[1])
        rt = register_number(operands[2])

        opcode = 0b000101

        return encode_r_type(
            opcode,
            rs,
            rt,
            rd
        )


    # --------------------------------------------------------
    # ADDI
    #
    # ADDI R3, R1, 10
    #
    # opcode = 001010
    # --------------------------------------------------------

    elif mnemonic == "ADDI":

        if len(operands) != 3:
            raise ValueError("ADDI syntax: ADDI Rt, Rs, immediate")

        rt = register_number(operands[0])
        rs = register_number(operands[1])
        immediate = int(operands[2], 0)

        opcode = 0b001010

        return encode_i_type(
            opcode,
            rs,
            rt,
            immediate
        )


    # --------------------------------------------------------
    # SUBI
    #
    # SUBI R3, R1, 10
    #
    # opcode = 001011
    # --------------------------------------------------------

    elif mnemonic == "SUBI":

        if len(operands) != 3:
            raise ValueError("SUBI syntax: SUBI Rt, Rs, immediate")

        rt = register_number(operands[0])
        rs = register_number(operands[1])
        immediate = int(operands[2], 0)

        opcode = 0b001011

        return encode_i_type(
            opcode,
            rs,
            rt,
            immediate
        )


    # --------------------------------------------------------
    # SLTI
    #
    # SLTI R3, R1, 10
    #
    # opcode = 001100
    # --------------------------------------------------------

    elif mnemonic == "SLTI":

        if len(operands) != 3:
            raise ValueError("SLTI syntax: SLTI Rt, Rs, immediate")

        rt = register_number(operands[0])
        rs = register_number(operands[1])
        immediate = int(operands[2], 0)

        opcode = 0b001100

        return encode_i_type(
            opcode,
            rs,
            rt,
            immediate
        )
        # --------------------------------------------------------
        
    # MOV
    #
    # MOV R3, R1
    #
    # opcode = 000111
    # rs = source
    # rd = destination
    # --------------------------------------------------------

    elif mnemonic == "MOV":

        if len(operands) != 2:
            raise ValueError("MOV syntax: MOV Rd, Rs")

        rd = register_number(operands[0])
        rs = register_number(operands[1])

        opcode = 0b000111

        instruction = (
            (opcode << 26)
            | (rs << 21)
            | (rd << 11)
        )

        return instruction
    # --------------------------------------------------------
    # HLT
    # --------------------------------------------------------

    elif mnemonic == "HLT":

        if len(operands) != 0:
            raise ValueError("HLT takes no operands")

        return 0xFC000000
    # --------------------------------------------------------
    # LW
    #
    # LW R1, 4(R2)
    #
    # opcode = 001000
    #
    # R1 = Memory[R2 + 4]
    # --------------------------------------------------------

    elif mnemonic == "LW":

        if len(operands) != 2:
            raise ValueError(
                "LW syntax: LW Rt, offset(Rs)"
            )

        rt = register_number(operands[0])

        immediate, rs = parse_memory_operand(
            operands[1]
        )

        opcode = 0b001000

        return encode_i_type(
            opcode,
            rs,
            rt,
            immediate
        )
    # --------------------------------------------------------
    # SW
    #
    # SW R1, 4(R2)
    #
    # opcode = 001001
    #
    # Memory[R2 + 4] = R1
    # --------------------------------------------------------

    elif mnemonic == "SW":

        if len(operands) != 2:
            raise ValueError(
                "SW syntax: SW Rt, offset(Rs)"
            )

        rt = register_number(operands[0])

        immediate, rs = parse_memory_operand(
            operands[1]
        )

        opcode = 0b001001

        return encode_i_type(
            opcode,
            rs,
            rt,
            immediate
        )
        # --------------------------------------------------------
    # BEQZ
    #
    # BEQZ R1, LOOP
    #
    # Branch if R1 == 0
    #
    # opcode = 001110
    # --------------------------------------------------------

    elif mnemonic == "BEQZ":

        if len(operands) != 2:
            raise ValueError("BEQZ syntax: BEQZ Rs, label")

        rs = register_number(operands[0])
        label = operands[1]

        if labels is None or label not in labels:
            raise ValueError(
                f"Undefined label: {label}"
            )

        target_address = labels[label]

        # Branch offset is relative to PC + 4
        offset = target_address - (current_address + 1)

        opcode = 0b001110

        return encode_branch(
            opcode,
            rs,
            offset
        )
        # --------------------------------------------------------
    # BNEQZ
    #
    # BNEQZ R1, LOOP
    #
    # Branch if R1 != 0
    #
    # opcode = 001101
    # --------------------------------------------------------

    elif mnemonic == "BNEQZ":

        if len(operands) != 2:
            raise ValueError("BNEQZ syntax: BNEQZ Rs, label")

        rs = register_number(operands[0])
        label = operands[1]

        if labels is None or label not in labels:
            raise ValueError(
                f"Undefined label: {label}"
            )

        target_address = labels[label]

        # Branch offset is relative to PC + 4
        offset = target_address - (current_address + 1)

        opcode = 0b001101

        return encode_branch(
            opcode,
            rs,
            offset
        )
        # --------------------------------------------------------
    # J
    #
    # J LOOP
    #
    # opcode = 010000
    # --------------------------------------------------------

    elif mnemonic == "J":

        if len(operands) != 1:
            raise ValueError("J syntax: J label")

        label = operands[0]

        if labels is None or label not in labels:
            raise ValueError(
                f"Undefined label: {label}"
            )

        target_address = labels[label]

        # Jump target is an instruction address.
        # CPU adds the lower 2 zero bits internally.
        if target_address < 0 or target_address > 0x03FFFFFF:
            raise ValueError(
                f"Jump target out of range: {label}"
            )

        opcode = 0b010000

        return (
            (opcode << 26)
            | target_address
        )
    # --------------------------------------------------------
    # Unknown instruction
    # --------------------------------------------------------

    else:

        raise ValueError(
            f"Unknown instruction: {mnemonic}"
        )


# ------------------------------------------------------------
# Assemble complete program
# ------------------------------------------------------------

def assemble_program(source):

    machine_code = []

    lines = source.splitlines()

    # --------------------------------------------------------
    # PASS 1
    # Find labels and their instruction addresses
    # --------------------------------------------------------

    labels = {}

    instruction_address = 0

    for line_number, line in enumerate(lines, start=1):

        # Remove comments
        line = line.split("#")[0].strip()

        if not line:
            continue

        # Check for label
        if ":" in line:

            label, remaining = line.split(":", 1)

            label = label.strip()

            if not label:
                raise ValueError(
                    f"Line {line_number}: Empty label"
                )

            if label in labels:
                raise ValueError(
                    f"Line {line_number}: Duplicate label '{label}'"
                )

            labels[label] = instruction_address

            # There may be an instruction after the label
            line = remaining.strip()

            if not line:
                continue

        instruction_address += 1


    # --------------------------------------------------------
    # PASS 2
    # Generate machine code
    # --------------------------------------------------------

    instruction_address = 0

    for line_number, line in enumerate(lines, start=1):

        try:

            # Remove comments
            line = line.split("#")[0].strip()

            if not line:
                continue

            # Remove label
            if ":" in line:

                _, line = line.split(":", 1)

                line = line.strip()

                if not line:
                    continue

            instruction = assemble_instruction(
                     line,
                    labels,
                    instruction_address
                )

            if instruction is not None:

                machine_code.append(instruction)

                instruction_address += 1

        except ValueError as error:

            raise ValueError(
                f"Line {line_number}: {error}"
            )

    return machine_code

# ------------------------------------------------------------
# Main program - TXT file to HEX file
# ------------------------------------------------------------

import sys
import os


def write_hex_file(machine_code, output_file):
    with open(output_file, "w") as file:

        for instruction in machine_code:
            file.write(f"{instruction:08X}\n")


if __name__ == "__main__":

    # Check command-line arguments
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage:")
        print("  python assembler.py input.txt")
        print("  python assembler.py input.txt output.hex")
        sys.exit(1)

    input_file = sys.argv[1]

    # If output filename is not given,
    # create one automatically
    if len(sys.argv) == 3:
        output_file = sys.argv[2]
    else:
        output_file = os.path.splitext(input_file)[0] + ".hex"

    # Check input file
    if not os.path.isfile(input_file):
        print(f"ERROR: Input file not found: {input_file}")
        sys.exit(1)

    try:

        # Read assembly program
        with open(input_file, "r") as file:
            program = file.read()

        # Assemble
        machine_code = assemble_program(program)

        # Write HEX file
        write_hex_file(machine_code, output_file)

        print("ASSEMBLY SUCCESSFUL")
        print("===================")
        print(f"Input file : {input_file}")
        print(f"Output file: {output_file}")
        print(f"Instructions: {len(machine_code)}")

        print("\nMachine Code:")
        for address, instruction in enumerate(machine_code):
            print(
                f"{address:04d} : "
                f"{instruction:08X}"
            )

    except ValueError as error:

        print("\nASSEMBLER ERROR:")
        print(error)

    except Exception as error:

        print("\nERROR:")
        print(error)