"""
Firmware loader para el Debug Unit del proyecto RISC-V (Windows).

Protocolo (derivado del RTL: du_master.v + du_imem_loader.v):

  1) Host -> FPGA : 6 bytes de comando
        [0]    = 0x01               (CMD_LOAD_FW)
        [1..4] = payload 32-bit LE  (ignorado, se manda 0)
        [5]    = checksum XOR de los bytes 0..4

  2) Host -> FPGA : 4 bytes little-endian con N = cantidad de instrucciones.

  3) Host -> FPGA : N * 4 bytes little-endian (una instruccion RV32I por cada 4 bytes).

  4) FPGA -> Host : respuesta de 5 bytes
        [0]    = status (0x00 OK, 0x01 ERROR, 0x02 BUSY)
        [1..4] = data 32-bit LE

UART: 115200 8N1 (coincide con rtl/top.v y rtl/uart/top_uart.v).

Uso:
    python load_program_windows.py <COM> <baudrate> <file.bin>
    python load_program_windows.py COM3 115200 test_program.bin
    python load_program_windows.py 3    115200 test_program.bin
    python load_program_windows.py COM3 115200 test_program.bin --no-halt
"""

import serial
import struct
import sys
import time


# ----- Constantes del protocolo (ver du_master.v) -----------------------
CMD_LOAD_FW      = 0x01
CMD_STATUS       = 0x0F
STATUS_OK        = 0x00
STATUS_ERROR     = 0x01
STATUS_BUSY      = 0x02

HALT_INSTRUCTION = 0x1A1A1A1A


def open_serial(port_arg: str, baudrate: int) -> serial.Serial:
    """Abre el puerto COM. Acepta 'COM3' o solo '3'."""
    port_arg = port_arg.strip()
    port_name = f"COM{port_arg}" if port_arg.isdigit() else port_arg.upper()

    ser = serial.Serial(
        port=port_name,
        baudrate=baudrate,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=5.0,
    )
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return ser


def build_cmd_frame(opcode: int, payload: int = 0) -> bytes:
    """Construye el frame de comando de 6 bytes (opcode + payload LE + XOR)."""
    payload_bytes = struct.pack('<I', payload & 0xFFFFFFFF)
    checksum = opcode
    for b in payload_bytes:
        checksum ^= b
    return bytes([opcode]) + payload_bytes + bytes([checksum & 0xFF])


def read_response(ser: serial.Serial) -> tuple:
    """Lee la respuesta de 5 bytes (status + data LE)."""
    resp = ser.read(5)
    print(f"RX raw bytes  : {resp.hex()}")
    if len(resp) < 5:
        raise TimeoutError(f"Timeout: recibidos {len(resp)}/5 bytes de respuesta")
    status = resp[0]
    data = struct.unpack('<I', resp[1:5])[0]
    return status, data


def status_name(status: int) -> str:
    return {
        STATUS_OK:    "OK",
        STATUS_ERROR: "ERROR",
        STATUS_BUSY:  "BUSY",
    }.get(status, f"UNKNOWN(0x{status:02X})")


def load_firmware(ser: serial.Serial, file_path: str, append_halt: bool = True) -> bool:
    """Carga el firmware en la IMEM usando el protocolo del debug unit."""
    # --- Leer binario ---
    with open(file_path, 'rb') as f:
        data = f.read()

    if len(data) == 0:
        print("Error: el archivo esta vacio")
        return False
    if len(data) % 4 != 0:
        print(f"Error: el tamano del firmware ({len(data)} bytes) no es multiplo de 4")
        return False

    # --- Descomponer en instrucciones de 32 bits ---
    instructions = [data[i:i + 4] for i in range(0, len(data), 4)]

    if append_halt:
        instructions.append(struct.pack('<I', HALT_INSTRUCTION))
        print(f"Halt 0x{HALT_INSTRUCTION:08X} agregado al final del firmware")

    n = len(instructions)
    print(f"Firmware: {n} instrucciones ({n * 4} bytes)")

    # --- Verificar sincronizacion con un comando valido ---
    # El protocolo no tiene byte start-of-frame, por eso no conviene inyectar
    # frames nulos: si la FSM esta desfasada, pueden empeorar la alineacion.
    print("Verificando debug unit con CMD_STATUS...")
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    time.sleep(0.05)

    frame_status = build_cmd_frame(CMD_STATUS, 0)
    print(f"TX status cmd : {frame_status.hex()}")
    ser.write(frame_status)
    ser.flush()

    try:
        status, status_data = read_response(ser)
    except TimeoutError as e:
        print(f"Error: {e}")
        print("Revisa que la FPGA este programada, libera reset fisico y vuelve a intentar.")
        return False

    print(f"RX status resp: status={status_name(status)} data=0x{status_data:08X}")
    if status != STATUS_OK:
        return False

    ser.reset_input_buffer()
    time.sleep(0.05)

    # --- 1) Enviar CMD_LOAD_FW ---
    frame = build_cmd_frame(CMD_LOAD_FW, 0)
    print(f"TX cmd frame  : {frame.hex()}")
    ser.write(frame)
    ser.flush()

    # Pausa generosa para que el FSM procese el comando completo
    # y llegue a S_LOAD_FW antes de recibir el size
    time.sleep(0.5)

    # --- 2) Enviar size (N) en little-endian ---
    size_bytes = struct.pack('<I', n)
    print(f"TX size       : {size_bytes.hex()} (N = {n})")
    ser.write(size_bytes)
    ser.flush()
    time.sleep(0.05)

    # --- 3) Enviar N instrucciones ---
    print(f"TX instructions ...")
    for idx, instr in enumerate(instructions):
        ser.write(instr)
        ser.flush()
        time.sleep(0.001)  # 1ms entre instrucciones
        word = struct.unpack('<I', instr)[0]
        print(f"  [{idx:3d}] 0x{word:08X}")

    # Pausa final antes de leer respuesta
    time.sleep(0.2)

    # --- 4) Leer respuesta de 5 bytes ---
    try:
        status, resp_data = read_response(ser)
    except TimeoutError as e:
        print(f"Error: {e}")
        return False

    print(f"RX response   : status={status_name(status)} data=0x{resp_data:08X}")
    return status == STATUS_OK


def main():
    if len(sys.argv) < 4:
        print("Uso: python load_program_windows.py <COM> <baudrate> <file.bin> [--no-halt]")
        print("Ej.: python load_program_windows.py COM3 115200 test_program.bin")
        sys.exit(1)

    port_arg  = sys.argv[1]
    baudrate  = int(sys.argv[2])
    file_path = sys.argv[3]
    append_halt = '--no-halt' not in sys.argv[4:]

    ser = open_serial(port_arg, baudrate)
    try:
        ok = load_firmware(ser, file_path, append_halt=append_halt)
        if ok:
            print("Firmware cargado correctamente")
            sys.exit(0)
        else:
            print("Fallo la carga del firmware")
            sys.exit(2)
    finally:
        ser.close()


if __name__ == "__main__":
    main()
