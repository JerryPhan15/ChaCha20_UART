import serial

PORT = "COM5"      # hoặc /dev/ttyUSB0
BAUD = 115200

# RFC 8439 expected keystream (64 bytes)
expected = bytes.fromhex(
    "10f1e7e4d13b5915500fdd1fa32071c4"
    "c7d1f4c733c068030422aa9ac3d46c4e"
    "d2826446079faa0914c2d705d98b02a2"
    "b5129cd1de164eb9cbd083e8a2503c4e"
)

ser = serial.Serial(PORT, BAUD, timeout=2)

data = ser.read(64)

print("RX:", data.hex())
print("EXP:", expected.hex())

if data == expected:
    print("ChaCha20 FPGA PASS")
else:
    print("FAIL")
