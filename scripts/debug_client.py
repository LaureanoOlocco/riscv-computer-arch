#!/usr/bin/env python3
"""
Debug Client for RISC-V Debug Unit
Implements the bidirectional command protocol over UART.

Command frame (host → FPGA): 6 bytes
    Byte 0:   OPCODE
    Byte 1-4: PAYLOAD (32-bit, little-endian)
    Byte 5:   CHECKSUM (XOR of bytes 0-4)

Response frame (FPGA → host): 5 bytes
    Byte 0:   STATUS (0x00=OK, 0x01=ERROR, 0x02=BUSY)
    Byte 1-4: DATA (32-bit, little-endian)
"""

import struct
import sys
import time
import serial


# Command opcodes
CMD_LOAD_FW   = 0x01
CMD_RUN       = 0x02
CMD_STEP      = 0x03
CMD_HALT      = 0x04
CMD_READ_REG  = 0x05
CMD_READ_MEM  = 0x06
CMD_WRITE_REG = 0x07
CMD_WRITE_MEM = 0x08
CMD_SET_BKP   = 0x09
CMD_CLR_BKP   = 0x0A
CMD_RESET     = 0x0B
CMD_STATUS    = 0x0F

# Response status codes
STATUS_OK    = 0x00
STATUS_ERROR = 0x01
STATUS_BUSY  = 0x02

# XMODEM constants
SOT = 0x01
EOT = 0x04
ACK = 0x05
NAK = 0x15
BLOCK_SIZE = 128
PAD_BYTE = 0x1A


class DebugClient:
    """RISC-V Debug Unit client over UART."""

    def __init__(self, port, baudrate=115200, timeout=2.0):
        """Initialize serial connection.

        Args:
            port: Serial port (e.g., '/dev/ttyUSB0' or 'COM3')
            baudrate: UART baud rate
            timeout: Read timeout in seconds
        """
        self.ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            stopbits=serial.STOPBITS_ONE,
            parity=serial.PARITY_NONE,
            timeout=timeout
        )
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

    def close(self):
        """Close serial connection."""
        if self.ser and self.ser.is_open:
            self.ser.close()

    def _build_frame(self, opcode, payload=0):
        """Build a 6-byte command frame.

        Args:
            opcode: 8-bit command opcode
            payload: 32-bit payload (default 0)

        Returns:
            bytes: 6-byte frame
        """
        payload_bytes = struct.pack('<I', payload & 0xFFFFFFFF)
        checksum = opcode
        for b in payload_bytes:
            checksum ^= b
        checksum &= 0xFF
        return bytes([opcode]) + payload_bytes + bytes([checksum])

    def _send_frame(self, opcode, payload=0):
        """Send a 6-byte command frame over UART.

        Args:
            opcode: 8-bit command opcode
            payload: 32-bit payload

        Returns:
            tuple: (status, data) from response
        """
        frame = self._build_frame(opcode, payload)
        self.ser.write(frame)
        self.ser.flush()
        return self._recv_response()

    def _recv_response(self):
        """Receive a 5-byte response frame.

        Returns:
            tuple: (status: int, data: int)

        Raises:
            TimeoutError: If response not received within timeout
        """
        resp = self.ser.read(5)
        if len(resp) < 5:
            raise TimeoutError(
                f"Timeout: received {len(resp)}/5 bytes"
            )
        status = resp[0]
        data = struct.unpack('<I', resp[1:5])[0]
        return status, data

    def _check_status(self, status, cmd_name):
        """Check response status and raise on error.

        Args:
            status: Response status byte
            cmd_name: Command name for error messages

        Raises:
            RuntimeError: If status indicates error or busy
        """
        if status == STATUS_ERROR:
            raise RuntimeError(f"{cmd_name}: FPGA returned ERROR")
        elif status == STATUS_BUSY:
            raise RuntimeError(f"{cmd_name}: FPGA returned BUSY")

    # =================================================================
    # Public API
    # =================================================================

    def load_fw(self, filepath):
        """Load firmware binary via XMODEM protocol.

        Sends CMD_LOAD_FW to activate du_imem_loader, then transmits
        the binary file using the XMODEM protocol.

        Args:
            filepath: Path to .bin firmware file

        Returns:
            bool: True on success
        """
        # Send CMD_LOAD_FW
        status, _ = self._send_frame(CMD_LOAD_FW)
        self._check_status(status, "LOAD_FW")

        # Wait for NAK from loader (ready signal)
        while True:
            byte = self.ser.read(1)
            if len(byte) == 0:
                continue
            if byte[0] == NAK:
                break

        # Read binary file
        with open(filepath, 'rb') as f:
            data = f.read()

        # Send via XMODEM
        block_num = 1
        offset = 0

        while offset < len(data):
            block = data[offset:offset + BLOCK_SIZE]
            # Pad last block
            if len(block) < BLOCK_SIZE:
                block += bytes([PAD_BYTE] * (BLOCK_SIZE - len(block)))

            # Calculate checksum
            checksum = sum(block) & 0xFF

            # Build XMODEM packet
            packet = bytes([SOT, block_num & 0xFF, (~block_num) & 0xFF])
            packet += block
            packet += bytes([checksum])

            # Send and wait for ACK
            self.ser.write(packet)
            self.ser.flush()

            resp = self.ser.read(1)
            if len(resp) == 0 or resp[0] != ACK:
                print(f"XMODEM: Block {block_num} NAK/timeout, retrying...")
                continue

            block_num += 1
            offset += BLOCK_SIZE

        # Send EOT
        self.ser.write(bytes([EOT]))
        self.ser.flush()
        resp = self.ser.read(1)

        if len(resp) > 0 and resp[0] == ACK:
            print(f"Firmware loaded: {len(data)} bytes ({block_num - 1} blocks)")
            return True
        else:
            print("XMODEM: EOT not acknowledged")
            return False

    def run(self):
        """Start CPU in continuous mode.

        Returns:
            tuple: (status, data)
        """
        status, data = self._send_frame(CMD_RUN)
        self._check_status(status, "RUN")
        print("CPU running (continuous mode)")
        return status, data

    def step(self, n=1):
        """Execute N single-steps.

        Args:
            n: Number of steps (default 1, 0 is treated as 1)

        Returns:
            int: PC after last step
        """
        status, data = self._send_frame(CMD_STEP, n)
        self._check_status(status, "STEP")
        print(f"Stepped {n}x, PC = 0x{data:08X}")
        return data

    def halt(self):
        """Halt the CPU immediately.

        Returns:
            int: Current PC
        """
        status, data = self._send_frame(CMD_HALT)
        self._check_status(status, "HALT")
        print(f"CPU halted, PC = 0x{data:08X}")
        return data

    def read_reg(self, addr):
        """Read a single CPU register.

        Args:
            addr: Register address (0-31).
                  Use 0xFF for full dump (legacy du_regfile_tx).

        Returns:
            int: Register value (or 0 for full dump)
        """
        status, data = self._send_frame(CMD_READ_REG, addr)
        self._check_status(status, "READ_REG")
        if addr != 0xFF:
            print(f"x{addr} = 0x{data:08X}")
        return data

    def read_mem(self, addr):
        """Read a single word from data memory.

        Args:
            addr: 32-bit memory address.
                  Use 0xFFFFFFFF for full dump (legacy du_dmem_tx).

        Returns:
            int: Memory value
        """
        status, data = self._send_frame(CMD_READ_MEM, addr)
        self._check_status(status, "READ_MEM")
        print(f"[0x{addr:08X}] = 0x{data:08X}")
        return data

    def write_reg(self, addr, data):
        """Write a value to a CPU register.

        The command frame carries the register address; a second
        4-byte frame carries the data to write.

        Args:
            addr: Register address (0-31)
            data: 32-bit value to write
        """
        # Send CMD_WRITE_REG with register address
        frame = self._build_frame(CMD_WRITE_REG, addr)
        self.ser.write(frame)
        self.ser.flush()

        # Send 4-byte data word (little-endian)
        data_bytes = struct.pack('<I', data & 0xFFFFFFFF)
        self.ser.write(data_bytes)
        self.ser.flush()

        # Receive response
        status, resp_data = self._recv_response()
        self._check_status(status, "WRITE_REG")
        print(f"x{addr} <- 0x{data:08X}")

    def write_mem(self, addr, data):
        """Write a word to data memory.

        The command frame carries the address; a second 4-byte frame
        carries the data to write.

        Args:
            addr: 32-bit memory address
            data: 32-bit value to write
        """
        # Send CMD_WRITE_MEM with address
        frame = self._build_frame(CMD_WRITE_MEM, addr)
        self.ser.write(frame)
        self.ser.flush()

        # Send 4-byte data word (little-endian)
        data_bytes = struct.pack('<I', data & 0xFFFFFFFF)
        self.ser.write(data_bytes)
        self.ser.flush()

        # Receive response
        status, resp_data = self._recv_response()
        self._check_status(status, "WRITE_MEM")
        print(f"[0x{addr:08X}] <- 0x{data:08X}")

    def set_breakpoint(self, addr):
        """Set a hardware breakpoint.

        Args:
            addr: 32-bit instruction address
        """
        status, data = self._send_frame(CMD_SET_BKP, addr)
        self._check_status(status, "SET_BKP")
        print(f"Breakpoint set at 0x{addr:08X}")

    def clear_breakpoint(self, addr):
        """Clear a hardware breakpoint.

        Args:
            addr: 32-bit instruction address
        """
        status, data = self._send_frame(CMD_CLR_BKP, addr)
        self._check_status(status, "CLR_BKP")
        print(f"Breakpoint cleared at 0x{addr:08X}")

    def reset(self):
        """Reset the CPU."""
        status, data = self._send_frame(CMD_RESET)
        self._check_status(status, "RESET")
        print("CPU reset")

    def status(self):
        """Query CPU status.

        Returns:
            dict: {running: bool, halted: bool, bkp_hit: bool}
        """
        status, data = self._send_frame(CMD_STATUS)
        self._check_status(status, "STATUS")

        running = bool(data & 0x01)
        halted  = bool(data & 0x02)
        bkp_hit = bool(data & 0x04)

        print(f"Status: running={running}, halted={halted}, bkp_hit={bkp_hit}")
        return {
            'running': running,
            'halted': halted,
            'bkp_hit': bkp_hit
        }

    def dump_regs(self):
        """Dump all 32 registers using legacy du_regfile_tx.

        Sends CMD_READ_REG with payload 0xFF to activate the full dump.
        Then reads PC (4 bytes) + 32 registers (4 bytes each) = 132 bytes.

        Returns:
            tuple: (pc, regs[0..31])
        """
        status, _ = self._send_frame(CMD_READ_REG, 0xFF)
        self._check_status(status, "DUMP_REGS")

        # Read PC + 32 regs = 33 * 4 = 132 bytes
        raw = self.ser.read(132)
        if len(raw) < 132:
            raise TimeoutError(
                f"Dump regs: received {len(raw)}/132 bytes"
            )

        pc = struct.unpack('<I', raw[0:4])[0]
        regs = []
        for i in range(32):
            offset = 4 + i * 4
            val = struct.unpack('<I', raw[offset:offset + 4])[0]
            regs.append(val)

        print(f"PC  = 0x{pc:08X}")
        for i, val in enumerate(regs):
            print(f"x{i:2d} = 0x{val:08X}")

        return pc, regs


def main():
    """CLI entry point."""
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <port> <baudrate> [command] [args...]")
        print()
        print("Commands:")
        print("  load_fw <file>          Load firmware binary")
        print("  run                     Start continuous execution")
        print("  step [N]                Single-step N instructions")
        print("  halt                    Halt CPU")
        print("  read_reg <addr>         Read register (0-31, or 0xFF for dump)")
        print("  read_mem <addr>         Read memory word")
        print("  write_reg <addr> <data> Write register")
        print("  write_mem <addr> <data> Write memory word")
        print("  set_bkp <addr>          Set breakpoint")
        print("  clr_bkp <addr>          Clear breakpoint")
        print("  reset                   Reset CPU")
        print("  status                  Query status")
        sys.exit(1)

    port = sys.argv[1]
    baudrate = int(sys.argv[2])
    cmd = sys.argv[3] if len(sys.argv) > 3 else "status"

    client = DebugClient(port, baudrate)

    try:
        if cmd == "load_fw":
            client.load_fw(sys.argv[4])
        elif cmd == "run":
            client.run()
        elif cmd == "step":
            n = int(sys.argv[4], 0) if len(sys.argv) > 4 else 1
            client.step(n)
        elif cmd == "halt":
            client.halt()
        elif cmd == "read_reg":
            addr = int(sys.argv[4], 0)
            client.read_reg(addr)
        elif cmd == "read_mem":
            addr = int(sys.argv[4], 0)
            client.read_mem(addr)
        elif cmd == "write_reg":
            addr = int(sys.argv[4], 0)
            data = int(sys.argv[5], 0)
            client.write_reg(addr, data)
        elif cmd == "write_mem":
            addr = int(sys.argv[4], 0)
            data = int(sys.argv[5], 0)
            client.write_mem(addr, data)
        elif cmd == "set_bkp":
            addr = int(sys.argv[4], 0)
            client.set_breakpoint(addr)
        elif cmd == "clr_bkp":
            addr = int(sys.argv[4], 0)
            client.clear_breakpoint(addr)
        elif cmd == "reset":
            client.reset()
        elif cmd == "status":
            client.status()
        else:
            print(f"Unknown command: {cmd}")
            sys.exit(1)
    finally:
        client.close()


if __name__ == '__main__':
    main()
