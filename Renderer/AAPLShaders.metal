#include <metal_stdlib>

using namespace metal;

#include "AAPLShaderTypes.h"

struct Rectangle
{
    float4 color [[ id(RectangleArgumentBufferIDColor) ]];
    float2 size  [[ id(RectangleArgumentBufferIDSize) ]];
};

#ifdef USE_ARGUMENTS_BUFFER
    struct SceneArgumentBuffer {
        constant Rectangle *rects [[ id(SceneArgumentBufferIDRectangles) ]];
    };
#endif

struct VertexOut
{
    float4 position [[position]];
    float4 color [[shared]];
};

vertex VertexOut
vertexShader(                uint                 instanceID [[ instance_id ]],
                             uint                 vertexID   [[ vertex_id ]],
             #ifdef USE_ARGUMENTS_BUFFER
                    constant SceneArgumentBuffer *args       [[ buffer(VertexBufferIndexArgumentBuffer) ]]
             #else
                    constant Rectangle           *rects      [[ buffer(VertexBufferIndexArgumentBuffer) ]]
             #endif
             )
{
    #ifdef USE_ARGUMENTS_BUFFER
        const constant Rectangle *rects = args->rects;
    #endif

    const Rectangle rect = rects[instanceID];
    const vector_float4 color = rect.color;
    const vector_float2 size = rect.size;
    switch (vertexID) {
            // Top Left corner
            case 0: return { {     0,       0, 0, 1}, color };
            // Top Right corner
            case 1: return { {size.x,       0, 0, 1}, color };
            // Bottom Left corner
            case 2: return { {     0, -size.y, 0, 1}, color };
            // Bottom Right corner
            case 3: return { {size.x, -size.y, 0, 1}, color };
    }
    
    // Shouldn't get here. vertexCount is 4 should ensure 0 <= vertexID <= 3.
    return { float4(0), float4(0) };
}

fragment float4
fragmentShader(VertexOut in [[ stage_in ]])
{
    return in.color;
}
