
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <Windows.h>
#include <stdio.h>

#define uint uint32_t
#define uchar uint8_t

#define block_size 64

#define S11 7
#define S12 12
#define S13 17
#define S14 22
#define S21 5
#define S22 9
#define S23 14
#define S24 20
#define S31 4
#define S32 11
#define S33 16
#define S34 23
#define S41 6
#define S42 10
#define S43 15
#define S44 21

#define F(x, y, z) (((x) & (y)) | ((~x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & (~z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | (~z)))

#define ROTATE_LEFT(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

#define FF(a, b, c, d, x, s, ac)                    \
	{                                               \
		(a) += F((b), (c), (d)) + (x) + (uint)(ac); \
		(a) = ROTATE_LEFT((a), (s));                \
		(a) += (b);                                 \
	}

#define GG(a, b, c, d, x, s, ac)                    \
	{                                               \
		(a) += G((b), (c), (d)) + (x) + (uint)(ac); \
		(a) = ROTATE_LEFT((a), (s));                \
		(a) += (b);                                 \
	}

#define HH(a, b, c, d, x, s, ac)                    \
	{                                               \
		(a) += H((b), (c), (d)) + (x) + (uint)(ac); \
		(a) = ROTATE_LEFT((a), (s));                \
		(a) += (b);                                 \
	}

#define II(a, b, c, d, x, s, ac)                    \
	{                                               \
		(a) += I((b), (c), (d)) + (x) + (uint)(ac); \
		(a) = ROTATE_LEFT((a), (s));                \
		(a) += (b);                                 \
	}

__device__ constexpr uchar padding[block_size] = { 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

__device__ uint byteswap(uint word)
{
	return ((word >> 24) & 0x000000FF) | ((word >> 8) & 0x0000FF00) | ((word << 8) & 0x00FF0000) | ((word << 24) & 0xFF000000);
}

__device__ unsigned long long totalhashes;


__device__  void transform(uint state[4], const uchar block[block_size])
{
	uint a = state[0], b = state[1], c = state[2], d = state[3];
	uint x[16];

	for (uint i = 0, j = 0; j < block_size && i < 16; i++, j += 4)
	{
		x[i] = (uint)block[j] | ((uint)block[j + 1] << 8) |
			((uint)block[j + 2] << 16) | ((uint)block[j + 3] << 24);
	}

	FF(a, b, c, d, x[0], S11, 0xd76aa478);
	FF(d, a, b, c, x[1], S12, 0xe8c7b756);
	FF(c, d, a, b, x[2], S13, 0x242070db);
	FF(b, c, d, a, x[3], S14, 0xc1bdceee);
	FF(a, b, c, d, x[4], S11, 0xf57c0faf);
	FF(d, a, b, c, x[5], S12, 0x4787c62a);
	FF(c, d, a, b, x[6], S13, 0xa8304613);
	FF(b, c, d, a, x[7], S14, 0xfd469501);
	FF(a, b, c, d, x[8], S11, 0x698098d8);
	FF(d, a, b, c, x[9], S12, 0x8b44f7af);
	FF(c, d, a, b, x[10], S13, 0xffff5bb1);
	FF(b, c, d, a, x[11], S14, 0x895cd7be);
	FF(a, b, c, d, x[12], S11, 0x6b901122);
	FF(d, a, b, c, x[13], S12, 0xfd987193);
	FF(c, d, a, b, x[14], S13, 0xa679438e);
	FF(b, c, d, a, x[15], S14, 0x49b40821);

	GG(a, b, c, d, x[1], S21, 0xf61e2562);
	GG(d, a, b, c, x[6], S22, 0xc040b340);
	GG(c, d, a, b, x[11], S23, 0x265e5a51);
	GG(b, c, d, a, x[0], S24, 0xe9b6c7aa);
	GG(a, b, c, d, x[5], S21, 0xd62f105d);
	GG(d, a, b, c, x[10], S22, 0x2441453);
	GG(c, d, a, b, x[15], S23, 0xd8a1e681);
	GG(b, c, d, a, x[4], S24, 0xe7d3fbc8);
	GG(a, b, c, d, x[9], S21, 0x21e1cde6);
	GG(d, a, b, c, x[14], S22, 0xc33707d6);
	GG(c, d, a, b, x[3], S23, 0xf4d50d87);
	GG(b, c, d, a, x[8], S24, 0x455a14ed);
	GG(a, b, c, d, x[13], S21, 0xa9e3e905);
	GG(d, a, b, c, x[2], S22, 0xfcefa3f8);
	GG(c, d, a, b, x[7], S23, 0x676f02d9);
	GG(b, c, d, a, x[12], S24, 0x8d2a4c8a);

	HH(a, b, c, d, x[5], S31, 0xfffa3942);
	HH(d, a, b, c, x[8], S32, 0x8771f681);
	HH(c, d, a, b, x[11], S33, 0x6d9d6122);
	HH(b, c, d, a, x[14], S34, 0xfde5380c);
	HH(a, b, c, d, x[1], S31, 0xa4beea44);
	HH(d, a, b, c, x[4], S32, 0x4bdecfa9);
	HH(c, d, a, b, x[7], S33, 0xf6bb4b60);
	HH(b, c, d, a, x[10], S34, 0xbebfbc70);
	HH(a, b, c, d, x[13], S31, 0x289b7ec6);
	HH(d, a, b, c, x[0], S32, 0xeaa127fa);
	HH(c, d, a, b, x[3], S33, 0xd4ef3085);
	HH(b, c, d, a, x[6], S34, 0x4881d05);
	HH(a, b, c, d, x[9], S31, 0xd9d4d039);
	HH(d, a, b, c, x[12], S32, 0xe6db99e5);
	HH(c, d, a, b, x[15], S33, 0x1fa27cf8);
	HH(b, c, d, a, x[2], S34, 0xc4ac5665);

	II(a, b, c, d, x[0], S41, 0xf4292244);
	II(d, a, b, c, x[7], S42, 0x432aff97);
	II(c, d, a, b, x[14], S43, 0xab9423a7);
	II(b, c, d, a, x[5], S44, 0xfc93a039);
	II(a, b, c, d, x[12], S41, 0x655b59c3);
	II(d, a, b, c, x[3], S42, 0x8f0ccc92);
	II(c, d, a, b, x[10], S43, 0xffeff47d);
	II(b, c, d, a, x[1], S44, 0x85845dd1);
	II(a, b, c, d, x[8], S41, 0x6fa87e4f);
	II(d, a, b, c, x[15], S42, 0xfe2ce6e0);
	II(c, d, a, b, x[6], S43, 0xa3014314);
	II(b, c, d, a, x[13], S44, 0x4e0811a1);
	II(a, b, c, d, x[4], S41, 0xf7537e82);
	II(d, a, b, c, x[11], S42, 0xbd3af235);
	II(c, d, a, b, x[2], S43, 0x2ad7d2bb);
	II(b, c, d, a, x[9], S44, 0xeb86d391);

	state[0] += a;
	state[1] += b;
	state[2] += c;
	state[3] += d;
}


__device__ void md5(const uchar* data, const uint size, uint result[4])
{
	uint state[4] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 }, i;

	for (i = 0; i + block_size <= size; i += block_size)
	{
		transform(state, data + i);
	}

	uint size_in_bits = size << 3;
	uchar buffer[block_size];

	memcpy(buffer, data + i, size - i);
	memcpy(buffer + size - i, padding, block_size - (size - i));
	memcpy(buffer + block_size - (2 * sizeof(uint)), &size_in_bits, sizeof(uint));

	transform(state, buffer);

	memcpy(result, state, 4 * sizeof(uint));
	if (result[0] == 0 && byteswap(result[1]) < 0x0fffffff) {
		printf("Hash found -------> %08x%08x%08x%08x\n", byteswap(result[0]), byteswap(result[1]), byteswap(result[2]), byteswap(result[3]));
		printf("For data   -------> ");
		for (int j = 0; j < size; j++) {
			printf("%02x", data[j]);
		}
		printf("\n\n");

	}
}

__global__ void test() {
	int thread = blockIdx.x * blockDim.x + threadIdx.x;
	uchar m[12];
	uint res[4];
	m[0] = (uchar)(thread & 0x000000ff);
	m[1] = (uchar)((thread >> 8) & 0x000000ff);
	m[2] = (uchar)((thread >> 16) & 0x000000ff);
	m[3] = (uchar)((thread >> 24) & 0x000000ff);

	for (unsigned long long i = 0; i < 0xffffffffffffffff; i++) {
		m[4] = (uchar)(i & 0x000000ff);
		m[5] = (uchar)((i >> 8) & 0x00000000000000ff);
		m[6] = (uchar)((i >> 16) & 0x00000000000000ff);
		m[7] = (uchar)((i >> 24) & 0x00000000000000ff);
		m[8] = (uchar)((i >> 32) & 0x00000000000000ff);
		m[9] = (uchar)((i >> 40) & 0x00000000000000ff);
		m[10] = (uchar)((i >> 48) & 0x00000000000000ff);
		m[11] = (uchar)((i >> 56) & 0x00000000000000ff);
		md5(m, 12, res);
	}
}

int main()
{
	test << <1024, 1024 >> > ();
    system("pause");
    return 0;
}