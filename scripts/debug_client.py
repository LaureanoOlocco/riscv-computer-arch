#!/usr/bin/env python3
"""
Debug Shell interactivo para RISC-V Debug Unit.

Uso:
    python debug_shell.py <puerto> <baudrate>
    python debug_shell.py COM3 115200
    python debug_shell.py /dev/ttyUSB0 115200
"""

import struct
import sys
import time
import serial

# ─── Opcodes ────────────────────────────────────────────────────────────────
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

STATUS_OK    = 0x00
STATUS_ERROR = 0x01
STATUS_BUSY  = 0x02

HALT_INSTRUCTION = 0x1A1A1A1A
BLOCK_SIZE = 128
PAD_BYTE   = 0x1A
SOT = 0x01
EOT = 0x04
ACK = 0x05
NAK = 0x15

# ─── Colores ANSI ────────────────────────────────────────────────────────────
R  = "\033[91m"
G  = "\033[92m"
Y  = "\033[93m"
B  = "\033[94m"
M  = "\033[95m"
C  = "\033[96m"
W  = "\033[97m"
DIM = "\033[2m"
RST = "\033[0m"
BOLD = "\033[1m"

def ok(msg):    print(f"  {G}✓{RST} {msg}")
def err(msg):   print(f"  {R}✗{RST} {msg}")
def info(msg):  print(f"  {C}→{RST} {msg}")
def warn(msg):  print(f"  {Y}!{RST} {msg}")


# ─── Cliente ─────────────────────────────────────────────────────────────────
class DebugClient:
    def __init__(self, port, baudrate=115200, timeout=2.0):
        self.ser = serial.Serial(
            port=port, baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            stopbits=serial.STOPBITS_ONE,
            parity=serial.PARITY_NONE,
            timeout=timeout,
        )
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

    def _build_frame(self, opcode, payload=0):
        pb = struct.pack('<I', payload & 0xFFFFFFFF)
        cs = opcode
        for b in pb:
            cs ^= b
        return bytes([opcode]) + pb + bytes([cs & 0xFF])

    def _send_frame(self, opcode, payload=0):
        self.ser.write(self._build_frame(opcode, payload))
        self.ser.flush()
        return self._recv_response()

    def _recv_response(self):
        resp = self.ser.read(5)
        if len(resp) < 5:
            raise TimeoutError(f"Timeout: {len(resp)}/5 bytes recibidos")
        status = resp[0]
        data   = struct.unpack('<I', resp[1:5])[0]
        return status, data

    def _check(self, status, name):
        if status == STATUS_ERROR:
            raise RuntimeError(f"{name}: FPGA respondió ERROR")
        if status == STATUS_BUSY:
            raise RuntimeError(f"{name}: FPGA respondió BUSY")

    # ── Comandos públicos ────────────────────────────────────────────────────

    def load_fw(self, filepath, append_halt=True):
        with open(filepath, 'rb') as f:
            data = f.read()
        if len(data) == 0 or len(data) % 4 != 0:
            raise ValueError("Archivo inválido (vacío o no múltiplo de 4 bytes)")

        instructions = [data[i:i+4] for i in range(0, len(data), 4)]
        if append_halt:
            instructions.append(struct.pack('<I', HALT_INSTRUCTION))

        n = len(instructions)
        info(f"Cargando {n} instrucciones...")

        # Flush FSM
        self.ser.write(bytes(6)); self.ser.flush()
        time.sleep(1.0); self.ser.reset_input_buffer(); time.sleep(0.1)

        # CMD_LOAD_FW
        self.ser.write(self._build_frame(CMD_LOAD_FW, 0)); self.ser.flush()
        time.sleep(0.5)

        # Tamaño
        self.ser.write(struct.pack('<I', n)); self.ser.flush()
        time.sleep(0.05)

        # Instrucciones
        for instr in instructions:
            self.ser.write(instr); self.ser.flush()
            time.sleep(0.001)

        time.sleep(0.2)
        status, _ = self._recv_response()
        self._check(status, "LOAD_FW")
        ok(f"Firmware cargado: {n} instrucciones ({n*4} bytes)")

    def run(self):
        status, data = self._send_frame(CMD_RUN)
        self._check(status, "RUN")
        ok("CPU corriendo (modo continuo)")

    def step(self, n=1):
        status, data = self._send_frame(CMD_STEP, n)
        self._check(status, "STEP")
        ok(f"{'Step' if n==1 else f'{n} steps'} → PC = {W}0x{data:08X}{RST}")
        return data

    def halt(self):
        status, data = self._send_frame(CMD_HALT)
        self._check(status, "HALT")
        ok(f"CPU detenida → PC = {W}0x{data:08X}{RST}")
        return data

    def reset(self):
        status, _ = self._send_frame(CMD_RESET)
        self._check(status, "RESET")
        ok("CPU reseteada")

    def status(self):
        status, data = self._send_frame(CMD_STATUS)
        self._check(status, "STATUS")
        running = bool(data & 0x01)
        halted  = bool(data & 0x02)
        bkp_hit = bool(data & 0x04)
        state = f"{G}RUNNING{RST}" if running else f"{Y}HALTED{RST}"
        print(f"  Estado  : {state}")
        print(f"  Halted  : {halted}")
        print(f"  BKP hit : {R+str(bkp_hit)+RST if bkp_hit else str(bkp_hit)}")
        return {'running': running, 'halted': halted, 'bkp_hit': bkp_hit}

    def read_reg(self, addr):
        if addr == 0xFF:
            return self.dump_regs()
        status, data = self._send_frame(CMD_READ_REG, addr)
        self._check(status, "READ_REG")
        abi = _abi_name(addr)
        print(f"  {M}x{addr:<2d}{RST} ({abi:<4}) = {W}0x{data:08X}{RST}  ({data})")
        return data

    def read_mem(self, addr):
        status, data = self._send_frame(CMD_READ_MEM, addr)
        self._check(status, "READ_MEM")
        print(f"  mem[{W}0x{addr:08X}{RST}] = {W}0x{data:08X}{RST}  ({data})")
        return data

    def write_reg(self, addr, data):
        frame = self._build_frame(CMD_WRITE_REG, addr)
        self.ser.write(frame); self.ser.flush()
        self.ser.write(struct.pack('<I', data & 0xFFFFFFFF)); self.ser.flush()
        status, _ = self._recv_response()
        self._check(status, "WRITE_REG")
        ok(f"x{addr} ({_abi_name(addr)}) ← 0x{data:08X}")

    def write_mem(self, addr, data):
        frame = self._build_frame(CMD_WRITE_MEM, addr)
        self.ser.write(frame); self.ser.flush()
        self.ser.write(struct.pack('<I', data & 0xFFFFFFFF)); self.ser.flush()
        status, _ = self._recv_response()
        self._check(status, "WRITE_MEM")
        ok(f"mem[0x{addr:08X}] ← 0x{data:08X}")

    def set_breakpoint(self, addr):
        status, _ = self._send_frame(CMD_SET_BKP, addr)
        self._check(status, "SET_BKP")
        ok(f"Breakpoint seteado en {W}0x{addr:08X}{RST}")

    def clear_breakpoint(self, addr):
        status, _ = self._send_frame(CMD_CLR_BKP, addr)
        self._check(status, "CLR_BKP")
        ok(f"Breakpoint borrado en {W}0x{addr:08X}{RST}")

    def dump_regs(self):
        status, _ = self._send_frame(CMD_READ_REG, 0xFF)
        self._check(status, "DUMP_REGS")
        raw = self.ser.read(132)
        if len(raw) < 132:
            raise TimeoutError(f"Dump: {len(raw)}/132 bytes")
        pc = struct.unpack('<I', raw[0:4])[0]
        regs = [struct.unpack('<I', raw[4+i*4:8+i*4])[0] for i in range(32)]
        print(f"\n  {BOLD}{C}PC{RST}  = {W}0x{pc:08X}{RST}")
        for i, val in enumerate(regs):
            abi  = _abi_name(i)
            mark = G if val != 0 else DIM
            print(f"  {M}x{i:<2d}{RST} {DIM}({abi:<4}){RST} = {mark}0x{val:08X}{RST}  ({val})")
        return pc, regs


# ─── ABI names ───────────────────────────────────────────────────────────────
_ABI = [
    "zero","ra","sp","gp","tp",
    "t0","t1","t2",
    "s0","s1",
    "a0","a1","a2","a3","a4","a5","a6","a7",
    "s2","s3","s4","s5","s6","s7","s8","s9","s10","s11",
    "t3","t4","t5","t6",
]
def _abi_name(i):
    return _ABI[i] if 0 <= i < 32 else "?"


# ─── Ayuda ───────────────────────────────────────────────────────────────────
HELP = f"""
{BOLD}{C}Comandos disponibles:{RST}

  {W}load <archivo.bin>{RST}          Carga firmware en IMEM
  {W}run{RST}                         Corre la CPU en modo continuo
  {W}step [N]{RST}                    Ejecuta N pasos (default 1)
  {W}halt{RST}                        Detiene la CPU
  {W}reset{RST}                       Resetea la CPU
  {W}status{RST}                      Estado actual de la CPU

  {W}rr <reg>{RST}                    Lee registro (0-31, o 0xFF para dump)
  {W}wr <reg> <valor>{RST}            Escribe registro
  {W}rm <addr>{RST}                   Lee palabra de memoria
  {W}wm <addr> <valor>{RST}           Escribe palabra de memoria

  {W}bkp <addr>{RST}                  Setea breakpoint
  {W}clr <addr>{RST}                  Borra breakpoint

  {W}help{RST}                        Muestra esta ayuda
  {W}exit / quit / q{RST}             Sale del shell

{DIM}Los valores se pueden escribir en hex (0x...) o decimal.{RST}
"""

def parse_int(s):
    return int(s, 0)

# ─── Shell principal ──────────────────────────────────────────────────────────
def shell(client):
    print(HELP)
    while True:
        try:
            line = input(f"{B}riscv{RST}{DIM}>{RST} ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if not line:
            continue

        parts = line.split()
        cmd   = parts[0].lower()

        try:
            if cmd in ('exit', 'quit', 'q'):
                break

            elif cmd == 'help':
                print(HELP)

            elif cmd == 'load':
                if len(parts) < 2:
                    err("Uso: load <archivo.bin>"); continue
                client.load_fw(parts[1])

            elif cmd == 'run':
                client.run()

            elif cmd == 'step':
                n = parse_int(parts[1]) if len(parts) > 1 else 1
                client.step(n)

            elif cmd == 'halt':
                client.halt()

            elif cmd == 'reset':
                client.reset()

            elif cmd == 'status':
                client.status()

            elif cmd == 'rr':
                if len(parts) < 2:
                    err("Uso: rr <reg>"); continue
                client.read_reg(parse_int(parts[1]))

            elif cmd == 'wr':
                if len(parts) < 3:
                    err("Uso: wr <reg> <valor>"); continue
                client.write_reg(parse_int(parts[1]), parse_int(parts[2]))

            elif cmd == 'rm':
                if len(parts) < 2:
                    err("Uso: rm <addr>"); continue
                client.read_mem(parse_int(parts[1]))

            elif cmd == 'wm':
                if len(parts) < 3:
                    err("Uso: wm <addr> <valor>"); continue
                client.write_mem(parse_int(parts[1]), parse_int(parts[2]))

            elif cmd == 'bkp':
                if len(parts) < 2:
                    err("Uso: bkp <addr>"); continue
                client.set_breakpoint(parse_int(parts[1]))

            elif cmd == 'clr':
                if len(parts) < 2:
                    err("Uso: clr <addr>"); continue
                client.clear_breakpoint(parse_int(parts[1]))

            else:
                err(f"Comando desconocido: '{cmd}'. Escribí {W}help{RST} para ver los comandos.")

        except (ValueError, IndexError):
            err("Argumento inválido")
        except TimeoutError as e:
            err(f"Timeout: {e}")
        except RuntimeError as e:
            err(str(e))
        except FileNotFoundError as e:
            err(str(e))


# ─── Entry point ──────────────────────────────────────────────────────────────
def main():
    if len(sys.argv) < 3:
        print(f"Uso: python debug_shell.py <puerto> <baudrate>")
        print(f"Ej.: python debug_shell.py COM3 115200")
        print(f"     python debug_shell.py /dev/ttyUSB0 115200")
        sys.exit(1)

    port     = sys.argv[1]
    baudrate = int(sys.argv[2])

    print(f"\n{BOLD}{C}RISC-V Debug Shell{RST}")
    print(f"{DIM}Conectando a {port} @ {baudrate} baud...{RST}")

    try:
        client = DebugClient(port, baudrate)
    except serial.SerialException as e:
        print(f"{R}Error al abrir puerto: {e}{RST}")
        sys.exit(1)

    print(f"{G}Conectado.{RST} Escribí {W}help{RST} para ver los comandos.\n")

    try:
        shell(client)
    finally:
        client.close()
        print(f"{DIM}Conexión cerrada.{RST}")


if __name__ == '__main__':
    main()