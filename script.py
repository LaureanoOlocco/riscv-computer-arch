import sys
import serial
import serial.tools.list_ports
import time

BAUDRATE = 115200

# Protocolo
START_CHAR = 0xFB
END_CHAR   = 0xFD
ERROR_CHAR = 0xFE

# Opcodes (coinciden con tu alu.v)
OPCODES = {
    'ADD': 0x20,  # 100000
    'SUB': 0x22,  # 100010
    'AND': 0x24,  # 100100
    'OR':  0x25,  # 100101
    'XOR': 0x26,  # 100110
    'SRA': 0x03,  # 000011
    'SRL': 0x02,  # 000010
    'NOR': 0x27   # 100111
}

def print_help():
    print("\n" + "="*60)
    print(" Interfaz UART <-> ALU")
    print("="*60)
    print(f"START: 0x{START_CHAR:02X}   END: 0x{END_CHAR:02X}   ERROR: 0x{ERROR_CHAR:02X}")
    print(f"Baudrate: {BAUDRATE}")
    print("\nTrama TX: START(1) + A(4, LE) + B(4, LE) + OP(1) + END(1) = 11 bytes")
    print("\nOperaciones soportadas:")
    for op, code in OPCODES.items():
        print(f"  {op:3s} -> 0x{code:02X}")
    print("="*60 + "\n")

def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    return [(i, p.device, (p.description or "")) for i, p in enumerate(ports)]

def select_serial_port():
    ports = list_serial_ports()
    print("\nPuertos serie disponibles:")
    print("-" * 60)
    if not ports:
        print("No se encontraron puertos.")
        return None
    for idx, dev, desc in ports:
        print(f"  [{idx}] {dev:16s} - {desc}")
    print("-" * 60)

    # Si hay uno solo, lo tomamos directo
    if len(ports) == 1:
        chosen = ports[0][1]
        print(f"Usando puerto único: {chosen}")
        return chosen

    try:
        sel = int(input("Elegí el número de puerto: ").strip())
        if 0 <= sel < len(ports):
            print(f"Puerto seleccionado: {ports[sel][1]}")
            return ports[sel][1]
        else:
            print("Índice fuera de rango.")
            return None
    except (ValueError, KeyboardInterrupt):
        print("Selección cancelada/ inválida.")
        return None

def parse_hex32(s):
    s = s.strip().lower().replace("_", "")
    if s.startswith("0x"):
        s = s[2:]
    if not s:
        raise ValueError("Cadena vacía")
    val = int(s, 16)
    if val < 0 or val > 0xFFFFFFFF:
        raise ValueError("Fuera de rango de 32 bits")
    return val

class SerialPortControl:
    def __init__(self, port):
        self.serial_port = serial.Serial(port, BAUDRATE, timeout=5)
        time.sleep(2)  
        self.serial_port.reset_input_buffer()
        self.serial_port.reset_output_buffer()
        print(f" Abierto {port} @ {BAUDRATE} baud")

    def close(self):
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
            print("Puerto serie cerrado.")

    def _read_exactly(self, nbytes: int) -> bytes:
        remaining = nbytes
        buf = bytearray()
        while remaining > 0:
            chunk = self.serial_port.read(remaining)
            if not chunk:
                break  
            buf.extend(chunk)
            remaining -= len(chunk)
        return bytes(buf)

    def send_operation(self, a_hex, b_hex, op_str):
        op = op_str.strip().upper()
        if op not in OPCODES:
            raise ValueError(f"Operación inválida. Usa: {', '.join(OPCODES.keys())}")

        a = parse_hex32(a_hex)
        b = parse_hex32(b_hex)
        opcode = OPCODES[op]

        pkt = bytearray()
        pkt.append(START_CHAR)
        pkt.extend(a.to_bytes(4, "little"))
        pkt.extend(b.to_bytes(4, "little"))
        pkt.append(opcode)
        pkt.append(END_CHAR)

        print("\n--- Enviando ---")
        print(f"START:   0x{START_CHAR:02X}")
        print(f"A:       0x{a:08X} -> {' '.join(f'{bb:02X}' for bb in a.to_bytes(4,'little'))}")
        print(f"B:       0x{b:08X} -> {' '.join(f'{bb:02X}' for bb in b.to_bytes(4,'little'))}")
        print(f"OPCODE:  0x{opcode:02X} ({op})")
        print(f"END:     0x{END_CHAR:02X}")
        print(f"Total:   {len(pkt)} bytes")
        print(f"RAW:     {' '.join(f'{bb:02X}' for bb in pkt)}")

        self.serial_port.reset_input_buffer()
        self.serial_port.reset_output_buffer()
        written = self.serial_port.write(pkt)
        self.serial_port.flush()
        print(f" Enviados {written} bytes. Esperando respuesta...")

        rx = self._read_exactly(4)

        if len(rx) == 0:
            print("Timeout: no se recibieron datos.")
            return None

        if len(rx) != 4:
            print(f"Error de recepción: se esperaban 4 bytes y llegaron {len(rx)}.")
            print(f"RX: {' '.join(f'{bb:02X}' for bb in rx)}")
            return None

        if all(bb == ERROR_CHAR for bb in rx):
            print("*** FPGA reportó ERROR (FE FE FE FE) ***")
            return None

        result = int.from_bytes(rx, "little", signed=False)
        print("\n--- Resultado ---")
        print(f"RX bytes: {' '.join(f'{bb:02X}' for bb in rx)}")
        print(f"Hex:      0x{result:08X}")
        print(f"Dec:      {result}")
        print(f"Bin:      0b{result:032b}")
        return result

def main():
    print_help()
    port = select_serial_port()
    if not port:
        print("\nNo se seleccionó puerto. Saliendo…")
        sys.exit(1)

    try:
        app = SerialPortControl(port)
    except Exception as e:
        print(f"No se pudo abrir el puerto: {e}")
        sys.exit(2)

    try:
        while True:
            try:
                a_hex = input('Operando A (Hex 32-bit, ej 0x12 o 12): ').strip()
                b_hex = input('Operando B (Hex 32-bit, ej 0x34 o 34): ').strip()
                op    = input('Operación (ADD, SUB, AND, OR, XOR, NOR, SRA, SRL): ').strip()
                app.send_operation(a_hex, b_hex, op)
            except KeyboardInterrupt:
                print("\nOperación cancelada por el usuario.")
            except ValueError as ve:
                print(f"Entrada inválida: {ve}")
            except serial.SerialException as se:
                print(f"Error de puerto serie: {se}")
                break

            again = input('\n¿Nueva operación? (y/n): ').strip().lower()
            if again != 'y':
                break
    finally:
        app.close()
        print("\nPrograma terminado.")

if __name__ == "__main__":
    main()
