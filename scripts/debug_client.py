#!/usr/bin/env python3

import struct
import sys
import time
import serial

CMD_LOAD_FW    = 0x01
CMD_RUN        = 0x02
CMD_STEP       = 0x03
CMD_HALT       = 0x04
CMD_READ_REG   = 0x05
CMD_READ_MEM   = 0x06
CMD_WRITE_REG  = 0x07
CMD_WRITE_MEM  = 0x08
CMD_SET_BKP    = 0x09
CMD_CLR_BKP    = 0x0A
CMD_RESET      = 0x0B
CMD_STATUS     = 0x0F
CMD_READ_LATCH = 0x10

STATUS_OK    = 0x00
STATUS_ERROR = 0x01
STATUS_BUSY  = 0x02

HALT_INSTRUCTION = 0x1A1A1A1A

R = "\033[91m"
G = "\033[92m"
Y = "\033[93m"
C = "\033[96m"
W = "\033[97m"
RST = "\033[0m"

def ok(msg): print(f"  {G}✓{RST} {msg}")
def err(msg): print(f"  {R}✗{RST} {msg}")
def info(msg): print(f"  {C}→{RST} {msg}")

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

class DebugClient:
    def __init__(self, port, baudrate=115200, timeout=2.0):
        self.ser = serial.Serial(
            port=port,
            baudrate=baudrate,
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
        payload_bytes = struct.pack("<I", payload & 0xFFFFFFFF)

        checksum = opcode
        for b in payload_bytes:
            checksum ^= b

        return bytes([opcode]) + payload_bytes + bytes([checksum & 0xFF])

    def _recv_response(self):
        resp = self.ser.read(5)

        if len(resp) < 5:
            raise TimeoutError(f"{len(resp)}/5 bytes recibidos")

        status = resp[0]
        data = struct.unpack("<I", resp[1:5])[0]

        return status, data

    def _send_frame(self, opcode, payload=0):
        self.ser.write(self._build_frame(opcode, payload))
        self.ser.flush()

        time.sleep(0.01)

        return self._recv_response()

    def _check(self, status, name):
        if status == STATUS_ERROR:
            raise RuntimeError(f"{name}: FPGA respondió ERROR")

        if status == STATUS_BUSY:
            raise RuntimeError(f"{name}: FPGA respondió BUSY")

    def resync_uart(self):
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        time.sleep(0.05)

    def sync_uart(self):
        self.resync_uart()
        status, data = self._send_frame(CMD_STATUS)
        self._check(status, "SYNC")
        self.ser.reset_input_buffer()
        ok("Debug unit sincronizada")
        return data

    def reset(self):
        self.resync_uart()

        status, _ = self._send_frame(CMD_RESET)

        self._check(status, "RESET")

        self.ser.reset_input_buffer()

        ok("CPU reseteada")

    def run(self):
        status, _ = self._send_frame(CMD_RUN)

        self._check(status, "RUN")

        ok("CPU corriendo")

    def halt(self):
        status, pc = self._send_frame(CMD_HALT)

        self._check(status, "HALT")

        ok(f"CPU detenida → PC = 0x{pc:08X}")

        return pc

    def step(self, n=1):
        status, pc = self._send_frame(CMD_STEP, n)

        self._check(status, "STEP")

        ok(f"{n} step(s) → PC = 0x{pc:08X}")

        return pc

    def status(self):
        status, data = self._send_frame(CMD_STATUS)

        self._check(status, "STATUS")

        running = bool(data & 0x01)
        halted = bool(data & 0x02)
        bkp_hit = bool(data & 0x04)

        if running:
            state = f"{G}RUNNING{RST}"
        elif halted:
            state = f"{Y}HALTED{RST}"
        else:
            state = f"{R}IDLE/UNKNOWN{RST}"

        print(f"  Estado  : {state}")
        print(f"  Running : {running}")
        print(f"  Halted  : {halted}")
        print(f"  BKP hit : {bkp_hit}")

        return {
            "running": running,
            "halted": halted,
            "bkp_hit": bkp_hit,
        }

    def read_reg(self, addr):
        if addr == 0xFF or addr == 255:
            return self.dump_regs()

        status, data = self._send_frame(CMD_READ_REG, addr)

        self._check(status, "READ_REG")

        print(f"  x{addr:<2d} ({_abi_name(addr):<4}) = 0x{data:08X}  ({data})")

        return data

    def dump_regs(self):
        # FIX IMPORTANTE:
        # Para rr 255, el hardware manda:
        #   132 bytes dump + 5 bytes response
        # No se puede usar _send_frame(), porque espera primero los 5 bytes.
        self.ser.write(self._build_frame(CMD_READ_REG, 0xFF))
        self.ser.flush()

        raw = self.ser.read(132)

        if len(raw) < 132:
            raise TimeoutError(f"Dump incompleto: {len(raw)}/132 bytes")

        status, _ = self._recv_response()

        self._check(status, "DUMP_REGS")

        pc = struct.unpack("<I", raw[0:4])[0]

        regs = []
        for i in range(32):
            val = struct.unpack("<I", raw[4+i*4:8+i*4])[0]
            regs.append(val)

        print()
        print(f"  PC = 0x{pc:08X}")

        for i, val in enumerate(regs):
            print(f"  x{i:<2d} ({_abi_name(i):<4}) = 0x{val:08X}  ({val})")

        return pc, regs

    def write_reg(self, addr, value):
        raise RuntimeError("WRITE_REG no está conectado en cpu_subsystem/cpu_core")

    def read_mem(self, addr):
        status, data = self._send_frame(CMD_READ_MEM, addr)

        self._check(status, "READ_MEM")

        print(f"  mem[0x{addr:08X}] = 0x{data:08X}  ({data})")

        return data

    def write_mem(self, addr, value):
        raise RuntimeError("WRITE_MEM no está conectado en cpu_subsystem/cpu_core")

    def set_breakpoint(self, addr):
        status, _ = self._send_frame(CMD_SET_BKP, addr)

        self._check(status, "SET_BKP")

        ok(f"Breakpoint seteado en 0x{addr:08X}")

    def clear_breakpoint(self, addr):
        status, _ = self._send_frame(CMD_CLR_BKP, addr)

        self._check(status, "CLR_BKP")

        ok(f"Breakpoint borrado en 0x{addr:08X}")

    def load_fw(self, filepath, append_halt=True):
        with open(filepath, "rb") as f:
            data = f.read()

        if len(data) == 0 or len(data) % 4 != 0:
            raise ValueError("Archivo inválido: vacío o no múltiplo de 4 bytes")

        instructions = [
            data[i:i+4]
            for i in range(0, len(data), 4)
        ]

        if append_halt:
            instructions.append(struct.pack("<I", HALT_INSTRUCTION))

        n = len(instructions)

        info(f"Cargando {n} instrucciones...")

        self.resync_uart()

        self.ser.write(self._build_frame(CMD_LOAD_FW, 0))
        self.ser.flush()

        time.sleep(0.2)

        self.ser.write(struct.pack("<I", n))
        self.ser.flush()

        time.sleep(0.05)

        for instr in instructions:
            self.ser.write(instr)
            self.ser.flush()
            time.sleep(0.001)

        status, _ = self._recv_response()

        self._check(status, "LOAD_FW")

        ok(f"Firmware cargado: {n} instrucciones ({n*4} bytes)")

def parse_int(s):
    return int(s, 0)

HELP = """
Comandos disponibles:

  load <archivo.bin>          Carga firmware en IMEM
  run                         Corre la CPU
  step [N]                    Ejecuta N pasos
  halt                        Detiene la CPU
  reset                       Resetea la CPU
  status                      Estado actual
  sync                        Limpia buffers y verifica CMD_STATUS

  rr <reg>                    Lee registro 0-31, o 255 / 0xFF para dump
  wr <reg> <valor>            No soportado: RTL no conecta escritura DU

  rm <addr>                   Lee memoria
  wm <addr> <valor>           No soportado: RTL no conecta escritura DU

  bkp <addr>                  Setea breakpoint
  clr <addr>                  Borra breakpoint

  help
  exit / quit / q
"""

def shell(client):
    print(HELP)

    while True:
        try:
            line = input("riscv> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if not line:
            continue

        parts = line.split()
        cmd = parts[0].lower()

        try:
            if cmd in ("exit", "quit", "q"):
                break

            elif cmd == "help":
                print(HELP)

            elif cmd == "load":
                if len(parts) < 2:
                    err("Uso: load <archivo.bin>")
                    continue

                client.load_fw(parts[1])

            elif cmd == "run":
                client.run()

            elif cmd == "step":
                n = parse_int(parts[1]) if len(parts) > 1 else 1
                client.step(n)

            elif cmd == "halt":
                client.halt()

            elif cmd == "reset":
                client.reset()

            elif cmd == "status":
                client.status()

            elif cmd == "sync":
                client.sync_uart()

            elif cmd == "rr":
                if len(parts) < 2:
                    err("Uso: rr <reg>")
                    continue

                client.read_reg(parse_int(parts[1]))

            elif cmd == "wr":
                if len(parts) < 3:
                    err("Uso: wr <reg> <valor>")
                    continue

                client.write_reg(parse_int(parts[1]), parse_int(parts[2]))

            elif cmd == "rm":
                if len(parts) < 2:
                    err("Uso: rm <addr>")
                    continue

                client.read_mem(parse_int(parts[1]))

            elif cmd == "wm":
                if len(parts) < 3:
                    err("Uso: wm <addr> <valor>")
                    continue

                client.write_mem(parse_int(parts[1]), parse_int(parts[2]))

            elif cmd == "bkp":
                if len(parts) < 2:
                    err("Uso: bkp <addr>")
                    continue

                client.set_breakpoint(parse_int(parts[1]))

            elif cmd == "clr":
                if len(parts) < 2:
                    err("Uso: clr <addr>")
                    continue

                client.clear_breakpoint(parse_int(parts[1]))

            else:
                err(f"Comando desconocido: {cmd}")

        except TimeoutError as e:
            err(f"Timeout: {e}")

        except ValueError:
            err("Argumento inválido")

        except RuntimeError as e:
            err(str(e))

        except FileNotFoundError as e:
            err(str(e))

def main():
    if len(sys.argv) < 3:
        print("Uso:")
        print("  python debug_client.py COM5 115200")
        sys.exit(1)

    port = sys.argv[1]
    baudrate = int(sys.argv[2])

    print()
    print("RISC-V Debug Shell")
    print(f"Conectando a {port} @ {baudrate} baud...")

    client = None

    try:
        client = DebugClient(port, baudrate)
        client.sync_uart()

    except serial.SerialException as e:
        print(f"{R}Error al abrir puerto: {e}{RST}")
        sys.exit(1)

    except (TimeoutError, RuntimeError) as e:
        print(f"{R}No se pudo sincronizar con la debug unit: {e}{RST}")
        print("Revisá que la FPGA esté programada, liberá reset físico y volvé a intentar.")
        if client:
            client.close()
        sys.exit(2)

    print("Conectado. Escribí help para ver comandos.")
    print()

    try:
        shell(client)

    finally:
        client.close()
        print("Conexión cerrada.")

if __name__ == "__main__":
    main()
