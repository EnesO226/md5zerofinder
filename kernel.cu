#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <Windows.h>
#include <string.h>
#include <stdint.h>
#include <cstdint>

__constant__ uint32_t K[64] = 
{   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 
};

__device__ uint32_t s0(uint32_t x) {
    return ((x >> 7) | (x << (32 - 7))) ^ ((x >> 18) | (x << (32 - 18))) ^ (x >> 3);
}

__device__ uint32_t s1(uint32_t x) {
    return ((x >> 17) | (x << (32 - 17))) ^ ((x >> 19) | (x << (32 - 19))) ^ (x >> 10);
}

__device__ uint32_t S0(uint32_t x) {
    return ((x >> 2) | (x << (32 - 2))) ^ ((x >> 13) | (x << (32 - 13))) ^ ((x >> 22) | (x << (32 - 22)));
}

__device__ uint32_t S1(uint32_t x) {
    return ((x >> 6) | (x << (32 - 6))) ^ ((x >> 11) | (x << (32 - 11))) ^ ((x >> 25) | (x << (32 - 25)));
}

__device__ uint32_t maj(uint32_t a, uint32_t b, uint32_t c) {
    return (a & b) ^ (a & c) ^ (b & c);
}

__device__ uint32_t ch(uint32_t e, uint32_t f, uint32_t g) {
    return (e & f) ^ (~e &  g);
}

__device__ void transform(uint32_t state[], uint32_t block[]) {

    uint32_t a = 0x6a09e667;
    uint32_t b = 0xbb67ae85;
    uint32_t c = 0x3c6ef372;
    uint32_t d = 0xa54ff53a;
    uint32_t e = 0x510e527f;
    uint32_t f = 0x9b05688c;
    uint32_t g = 0x1f83d9ab;
    uint32_t h = 0x5be0cd19;

    uint32_t a0 = 0x6a09e667;
    uint32_t b0 = 0xbb67ae85;
    uint32_t c0 = 0x3c6ef372;
    uint32_t d0 = 0xa54ff53a;
    uint32_t e0 = 0x510e527f;
    uint32_t f0 = 0x9b05688c;
    uint32_t g0 = 0x1f83d9ab;
    uint32_t h0 = 0x5be0cd19;

    uint32_t x[64];

    for (int i = 0; i < 16; i++) {
        x[i] = block[i];
    }

    for (int j = 16; j < 64; j++) {
        x[j] = x[j - 16] + s0(x[j - 15]) + x[j - 7] + s1(x[j - 2]);
    }

    for (int k = 0; k < 64; k++) {
        uint32_t sig1 = S1(e);
        uint32_t choose = ch(e, f, g);
        uint32_t temp1 = h + sig1 + choose + K[k] + x[k];
        uint32_t sig0 = S0(a);
        uint32_t majority = maj(a, b, c);
        uint32_t temp2 = sig0 + majority;

        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }

    a0 += a;
    b0 += b;
    c0 += c;
    d0 += d;
    e0 += e;
    f0 += f;
    g0 += g;
    h0 += h;

    if (a0 == 0xbbee11aa && b0 < 0xffffffff) {
        printf("Compressed hash ---> %08x%08x%08x%08x%08x%08x%08x%08x\n", a0, b0, c0, d0, e0, f0, g0, h0);
        printf("For input block ---> %08x%08x\n\n", block[0], block[1]);
    }
}

__global__ void Test() {
    int thread = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t msg[16];
    uint32_t state[4];
    for (int i = 0; i < 16; i++) {
        msg[i] = 0;
    }
    msg[0] = thread;
    
    for (uint64_t j = 0; j < 0xffffffffffffffff; j++) {
        msg[1] = (uint32_t)(j);
        msg[2] = 0x80000000;
        msg[15] = 0x00000040;
        transform(state, msg);
    }
}



int main()
{
    Test << <1024, 1024 >> > ();
    system("pause");
    return 0;
}