/* Bare-metal RV32I: F(0)=0, F(1)=1, so F(10)=55.
 * volatile keeps the calculation as a runtime loop in the optimized build.
 * Return value is written to the result/LED register by start.S.
 */
static volatile unsigned completed_iterations;

static void putchar_uart(unsigned char c)
{
    *(volatile unsigned char *)0x10000004u = c;
}

int main(void)
{
    volatile unsigned iterations = 10;
    unsigned a = 0, b = 1;
    for (unsigned i = 0; i < iterations; ++i) {
        unsigned next = a + b;
        a = b;
        b = next;
        ++completed_iterations;
    }

    /* Print a two-digit number without division or a standard library. */
    unsigned tens = 0, units = a;
    while (units >= 10) {
        units -= 10;
        ++tens;
    }
    putchar_uart('F');
    putchar_uart('=');
    putchar_uart((unsigned char)('0' + tens));
    putchar_uart((unsigned char)('0' + units));
    putchar_uart('\r');
    putchar_uart('\n');
    return (int)a;
}
