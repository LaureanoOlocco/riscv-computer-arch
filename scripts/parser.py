# RISC-V RV32I Assembler
# Reads a RISC-V assembly text file, converts each instruction to binary,
# and writes the binary instructions to a .bin file.
# Supports labels, comments, and ABI register names.

import sys
import os
import struct

# Instruction set for RV32I
opcode_map = {
    # U-type
    'lui':   ('0110111', 'U'),
    'auipc': ('0010111', 'U'),
    # J-type
    'jal':   ('1101111', 'J'),
    # I-type (jalr)
    'jalr':  ('1100111', 'I', '000'),
    # B-type
    'beq':   ('1100011', 'B', '000'),
    'bne':   ('1100011', 'B', '001'),
    'blt':   ('1100011', 'B', '100'),
    'bge':   ('1100011', 'B', '101'),
    'bltu':  ('1100011', 'B', '110'),
    'bgeu':  ('1100011', 'B', '111'),
    # I-type (loads)
    'lb':    ('0000011', 'I', '000'),
    'lh':    ('0000011', 'I', '001'),
    'lw':    ('0000011', 'I', '010'),
    'lbu':   ('0000011', 'I', '100'),
    'lhu':   ('0000011', 'I', '101'),
    # S-type
    'sb':    ('0100011', 'S', '000'),
    'sh':    ('0100011', 'S', '001'),
    'sw':    ('0100011', 'S', '010'),
    # I-type (arithmetic)
    'addi':  ('0010011', 'I', '000'),
    'slti':  ('0010011', 'I', '010'),
    'sltiu': ('0010011', 'I', '011'),
    'xori':  ('0010011', 'I', '100'),
    'ori':   ('0010011', 'I', '110'),
    'andi':  ('0010011', 'I', '111'),
    # I-type (shifts) - funct7 encoded in upper bits of immediate
    'slli':  ('0010011', 'I', '001', '0000000'),
    'srli':  ('0010011', 'I', '101', '0000000'),
    'srai':  ('0010011', 'I', '101', '0100000'),
    # R-type
    'add':   ('0110011', 'R', '000', '0000000'),
    'sub':   ('0110011', 'R', '000', '0100000'),
    'sll':   ('0110011', 'R', '001', '0000000'),
    'slt':   ('0110011', 'R', '010', '0000000'),
    'sltu':  ('0110011', 'R', '011', '0000000'),
    'xor':   ('0110011', 'R', '100', '0000000'),
    'srl':   ('0110011', 'R', '101', '0000000'),
    'sra':   ('0110011', 'R', '101', '0100000'),
    'or':    ('0110011', 'R', '110', '0000000'),
    'and':   ('0110011', 'R', '111', '0000000'),
}

# Register map: x0-x31 + ABI names
register_map = {f'x{i}': i for i in range(32)}
register_map.update({
    'zero': 0,
    'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    'fp': 8, 's0': 8,
    't0': 5, 't1': 6, 't2': 7,
    's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25,
    's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31,
})

# Load/store instructions that use offset(reg) syntax
LOAD_INSTRS = {'jalr', 'lb', 'lh', 'lw', 'lbu', 'lhu'}
STORE_INSTRS = {'sb', 'sh', 'sw'}


def strip_line(line):
    """Remove comments and whitespace from a line."""
    # Remove // and # comments
    for comment_char in ('//', '#'):
        idx = line.find(comment_char)
        if idx != -1:
            line = line[:idx]
    return line.strip()


def first_pass(lines):
    """First pass: collect label addresses. Returns (labels_dict, clean_lines).
    clean_lines is a list of (original_line_num, instruction_text) without labels or empty lines."""
    labels = {}
    clean_lines = []
    pc = 0  # byte address

    for line_num, raw_line in enumerate(lines, 1):
        line = strip_line(raw_line)
        if not line:
            continue

        # Check for label definition (label:)
        while ':' in line:
            colon_idx = line.index(':')
            label = line[:colon_idx].strip()
            if label:
                labels[label] = pc
            line = line[colon_idx + 1:].strip()

        if not line:
            continue

        clean_lines.append((line_num, line, pc))
        pc += 4

    return labels, clean_lines


def resolve_label(token, labels, pc):
    """Resolve a token that could be a label name or a numeric immediate.
    For branches/jumps, computes PC-relative offset."""
    if token in labels:
        offset = labels[token] - pc
        return str(offset)
    return token


def parse_instruction(line, labels=None, pc=0):
    """Parse a single line of RISC-V assembly into (instr, operand1, operand2, ...)."""
    parts = line.replace(',', '').split()
    instr = parts[0].lower()

    if instr in LOAD_INSTRS:
        # Format: instr rd, imm(rs1)
        rd = parts[1]
        if '(' in parts[2]:
            imm, rs1 = parts[2].split('(')
            rs1 = rs1.rstrip(')')
        else:
            # Also support: instr rd, rs1, imm
            rs1 = parts[2]
            imm = parts[3] if len(parts) > 3 else '0'
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rd, rs1, imm)

    if instr in STORE_INSTRS:
        # Format: instr rs2, imm(rs1)
        rs2 = parts[1]
        if '(' in parts[2]:
            imm, rs1 = parts[2].split('(')
            rs1 = rs1.rstrip(')')
        else:
            rs1 = parts[2]
            imm = parts[3] if len(parts) > 3 else '0'
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rs2, rs1, imm)

    if instr not in opcode_map:
        return None

    fmt = opcode_map[instr][1]

    if fmt == 'R':
        rd, rs1, rs2 = parts[1], parts[2], parts[3]
        return (instr, rd, rs1, rs2)

    elif fmt == 'I':
        rd, rs1, imm = parts[1], parts[2], parts[3]
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rd, rs1, imm)

    elif fmt == 'B':
        rs1, rs2, imm = parts[1], parts[2], parts[3]
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rs1, rs2, imm)

    elif fmt == 'U':
        rd, imm = parts[1], parts[2]
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rd, imm)

    elif fmt == 'J':
        rd, imm = parts[1], parts[2]
        if labels:
            imm = resolve_label(imm, labels, pc)
        return (instr, rd, imm)

    return None


def to_signed(val, bits):
    """Convert a Python int to a two's complement value within the given bit width."""
    mask = (1 << bits) - 1
    return val & mask


def convert_to_binary(instr_tuple):
    """Convert a parsed RISC-V instruction tuple to its 32-bit binary encoding."""
    instr, *operands = instr_tuple
    opcode, fmt = opcode_map[instr][0], opcode_map[instr][1]

    if fmt == 'R':
        # R-format: funct7 | rs2 | rs1 | funct3 | rd | opcode
        rd = f"{register_map[operands[0]]:05b}"
        rs1 = f"{register_map[operands[1]]:05b}"
        rs2 = f"{register_map[operands[2]]:05b}"
        funct3 = opcode_map[instr][2]
        funct7 = opcode_map[instr][3]
        binary_instr = f"{funct7}{rs2}{rs1}{funct3}{rd}{opcode}"

    elif fmt == 'I':
        # I-format: immediate[11:0] | rs1 | funct3 | rd | opcode
        rd = f"{register_map[operands[0]]:05b}"
        rs1 = f"{register_map[operands[1]]:05b}"
        funct3 = opcode_map[instr][2]

        if instr in ('slli', 'srli', 'srai'):
            # Shift immediate: funct7 | shamt[4:0] | rs1 | funct3 | rd | opcode
            funct7 = opcode_map[instr][3]
            shamt = f"{int(operands[2], 0) & 0x1f:05b}"
            imm = f"{funct7}{shamt}"
        else:
            imm = f"{to_signed(int(operands[2], 0), 12):012b}"

        binary_instr = f"{imm}{rs1}{funct3}{rd}{opcode}"

    elif fmt == 'S':
        # S-format: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
        rs2 = f"{register_map[operands[0]]:05b}"
        rs1 = f"{register_map[operands[1]]:05b}"
        imm = to_signed(int(operands[2], 0), 12)
        imm_4_0 = f"{imm & 0x1f:05b}"
        imm_11_5 = f"{(imm >> 5) & 0x7f:07b}"
        funct3 = opcode_map[instr][2]
        binary_instr = f"{imm_11_5}{rs2}{rs1}{funct3}{imm_4_0}{opcode}"

    elif fmt == 'B':
        # B-format: imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode
        rs1 = f"{register_map[operands[0]]:05b}"
        rs2 = f"{register_map[operands[1]]:05b}"
        imm = to_signed(int(operands[2], 0), 13)
        imm_12 = f"{(imm >> 12) & 0x1:01b}"
        imm_11 = f"{(imm >> 11) & 0x1:01b}"
        imm_10_5 = f"{(imm >> 5) & 0x3f:06b}"
        imm_4_1 = f"{(imm >> 1) & 0xf:04b}"
        funct3 = opcode_map[instr][2]
        binary_instr = f"{imm_12}{imm_10_5}{rs2}{rs1}{funct3}{imm_4_1}{imm_11}{opcode}"

    elif fmt == 'U':
        # U-format: imm[31:12] | rd | opcode
        rd = f"{register_map[operands[0]]:05b}"
        imm = f"{to_signed(int(operands[1], 0), 20):020b}"
        binary_instr = f"{imm}{rd}{opcode}"

    elif fmt == 'J':
        # J-format: imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode
        rd = f"{register_map[operands[0]]:05b}"
        imm = to_signed(int(operands[1], 0), 21)
        imm_20 = f"{(imm >> 20) & 0x1:01b}"
        imm_19_12 = f"{(imm >> 12) & 0xff:08b}"
        imm_11 = f"{(imm >> 11) & 0x1:01b}"
        imm_10_1 = f"{(imm >> 1) & 0x3ff:010b}"
        binary_instr = f"{imm_20}{imm_10_1}{imm_11}{imm_19_12}{rd}{opcode}"

    return int(binary_instr, 2)


def main():
    if len(sys.argv) < 2:
        print("Usage: python parser.py <input_file> [output_file]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(input_file)[0] + ".bin"

    with open(input_file, 'r') as f:
        lines = f.readlines()

    # First pass: collect labels
    labels, clean_lines = first_pass(lines)

    # Second pass: assemble instructions
    binary_instructions = []
    for line_num, instr_text, pc in clean_lines:
        try:
            instr_tuple = parse_instruction(instr_text, labels, pc)
            if instr_tuple is None:
                print(f"Warning: line {line_num}: unrecognized instruction '{instr_text}'")
                continue
            binary = convert_to_binary(instr_tuple)
            binary_instructions.append(binary)
        except Exception as e:
            print(f"Error: line {line_num}: '{instr_text}' -> {e}")
            sys.exit(1)

    # Write binary output
    with open(output_file, 'wb') as f:
        for binary in binary_instructions:
            f.write(struct.pack('<I', binary))

    print(f"Assembled {len(binary_instructions)} instructions -> {output_file}")

    # Print disassembly for verification
    if '--verbose' in sys.argv or '-v' in sys.argv:
        for i, (line_num, instr_text, pc) in enumerate(clean_lines):
            if i < len(binary_instructions):
                print(f"  0x{pc:04x}: 0x{binary_instructions[i]:08x}  {instr_text}")


if __name__ == "__main__":
    main()
