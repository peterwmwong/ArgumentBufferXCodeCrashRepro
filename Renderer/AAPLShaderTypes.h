#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// =======================================
//     Use Arguments Buffer (#define)
//                 OR
// Use Rectangles Buffer directly (#undef)
// =======================================
#define USE_ARGUMENTS_BUFFER
//#undef USE_ARGUMENTS_BUFFER
// =======================================

enum VertexBufferIndex
{
    VertexBufferIndexArgumentBuffer,
};

#ifdef USE_ARGUMENTS_BUFFER
    enum SceneArgumentBufferID
    {
        SceneArgumentBufferIDRectangles,
    };
#endif

typedef struct Rectangle
{
    vector_float4 color;
    vector_float2 size;
} Rectangle;

#endif /* ShaderTypes_h */
