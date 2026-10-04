#!/usr/bin/env python3
"""Compile a small freestanding C program for the existing UART-loaded CPU."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--cc', help='RISC-V bare-metal GCC executable')
    args = parser.parse_args()
    candidates = [args.cc] if args.cc else [
        'riscv64-unknown-elf-gcc', 'riscv32-unknown-elf-gcc',
        '/tools/Xilinx/Vitis/2024.2/gnu/riscv/lin/riscv64-unknown-elf/bin/riscv64-unknown-elf-gcc']
    cc = next((shutil.which(c) for c in candidates if shutil.which(c)), None)
    if not cc:
        parser.error('RISC-V bare-metal GCC not found; specify its path with --cc')
    prefix = Path(cc).name.removesuffix('gcc')
    def tool(name):
        path = Path(cc).parent / (prefix + name)
        if not path.is_file():
            parser.error(f'Missing companion tool: {path}')
        return str(path)

    source = args.source.resolve()
    output = ROOT / 'build' / 'c' / source.stem
    output.mkdir(parents=True, exist_ok=True)
    elf, binary, hexfile = [output / (source.stem + suffix)
                            for suffix in ('.elf', '.bin', '.hex')]
    subprocess.run([cc, '-march=rv32i', '-mabi=ilp32', '-Os', '-std=c11',
                    '-Wall', '-Wextra', '-ffreestanding', '-fno-builtin',
                    '-fno-stack-protector', '-fno-pic', '-msmall-data-limit=0',
                    '-mno-relax', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables',
                    '-nostdlib', '-nostartfiles', '-Wl,--no-relax', '-Wl,--build-id=none',
                    '-Wl,-T,' + str(ROOT / 'examples/c/link.ld'),
                    '-Wl,-Map,' + str(output / (source.stem + '.map')),
                    str(ROOT / 'examples/c/start.S'), str(source), '-o', str(elf)], check=True)
    subprocess.run([tool('objcopy'), '-O', 'binary', '--only-section=.text',
                    str(elf), str(binary)], check=True)
    data = binary.read_bytes()
    if not data or len(data) > 1024 or len(data) % 4:
        parser.error('Code must be 1–256 complete 32-bit instruction words')
    hexfile.write_text(''.join(f'{int.from_bytes(data[i:i+4], "little"):08x}\n'
                               for i in range(0, len(data), 4)))
    with (output / (source.stem + '.dis')).open('w') as listing:
        subprocess.run([tool('objdump'), '-d', str(elf)], stdout=listing, check=True)
    print(f'Built {len(data)} bytes ({len(data)//4}/256 instruction words): {hexfile}')
    print(f'Upload: python scripts/upload_program.py /dev/ttyUSB1 {hexfile.relative_to(ROOT)} --monitor')


if __name__ == '__main__':
    main()
