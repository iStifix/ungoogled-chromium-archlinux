#include <stdio.h>
#include <stdint.h>

int main() {
    printf("Architecture: ARM64 (aarch64)\n");
    printf("Pointer size: %zu bytes\n", sizeof(void*));
    
    // Проверка NEON (должен компилироваться)
    #ifdef __ARM_NEON
    printf("NEON: Available\n");
    #else
    printf("NEON: Not available\n");
    #endif
    
    // Проверка Crypto Extensions (НЕ должно быть на Cortex-A57)
    #ifdef __ARM_FEATURE_CRYPTO
    printf("Crypto: Available (WARNING: should NOT be present on Cortex-A57!)\n");
    #else
    printf("Crypto: Not available (correct for Cortex-A57)\n");
    #endif
    
    return 0;
}
