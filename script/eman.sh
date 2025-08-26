#!/bin/bash
set -e  # 發生錯誤時中斷 script

help() {
    cat <<EOF
Usage: eman <command> [options]

Available commands:
    help                         Show this help message
    c-compiler-version           Print GCC and Make version
    c-compiler-example           Compile & run C/C++ example
    check-verilator              Print Verilator version
    verilator-example            Compile & run Verilator example
EOF
}

c_compiler_version() {
    if command -v gcc >/dev/null 2>&1; then
        echo "GCC version:"
        gcc --version | head -n1
        echo "Make version:"
        make --version | head -n1
    else
        echo "GCC not found."
        exit 1
    fi
}

check_verilator() {
    if ! command -v verilator &>/dev/null; then
        echo "Verilator not found!"
        exit 1
    fi
    echo "Verilator version:"
    verilator --version
}

case "$1" in
    help|"") help ;;
    c-compiler-version) c_compiler_version ;;
    c-compiler-example) 
        shift
        cd "$1" && \
        make clean all;;
    check-verilator) check_verilator ;;
    verilator-example)
        shift
        cd "$1" && \
        make clean all;;
    *) echo "Unknown command: $1"; help; exit 1 ;;
esac