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

enum RectangleArgumentBufferID
{
    RectangleArgumentBufferIDColor = 0,
    RectangleArgumentBufferIDSize
};

#ifdef USE_ARGUMENTS_BUFFER
    enum SceneArgumentBufferID
    {
        SceneArgumentBufferIDRectangles,
    };
#endif

#endif /* ShaderTypes_h */
