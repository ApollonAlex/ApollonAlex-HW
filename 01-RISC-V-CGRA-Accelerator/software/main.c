#include <stdint.h>
#define HETA_BASE     ((uintptr_t)0x40000000u)
#define HETA_CTRL     (*(volatile uint32_t *)(HETA_BASE + 0x00u))
#define HETA_STATUS   (*(volatile uint32_t *)(HETA_BASE + 0x04u))
#define HETA_RUN      (*(volatile uint32_t *)(HETA_BASE + 0x08u))
#define HETA_VERSION  (*(volatile uint32_t *)(HETA_BASE + 0x10u))
#define SIGNATURE     (*(volatile uint32_t *)(uintptr_t)0x0000FFFCu)

void __attribute__((noreturn)) main(void) {
    SIGNATURE = 0;
    if (HETA_VERSION != 0x00010000u) {
        SIGNATURE = 0xBAD00001u;
        for (;;) { }
    }
    HETA_RUN = 32u;
    HETA_CTRL = 1u;
    uint32_t timeout = 100000u;
    while (((HETA_STATUS & 2u) == 0u) && timeout) {
        --timeout;
    }
    SIGNATURE = (HETA_STATUS & 2u) ? 0x48455441u : 0xBAD00002u;
    for (;;) { }
}
