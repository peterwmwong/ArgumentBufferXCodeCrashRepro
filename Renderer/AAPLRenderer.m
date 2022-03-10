@import simd;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLShaderTypes.h"

@implementation AAPLRenderer
{
    id<MTLDevice>              _device;
    id<MTLCommandQueue>        _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLBuffer>              _rectanglesBuffer;
    
    #ifdef USE_ARGUMENTS_BUFFER
        id<MTLBuffer>          _argumentBuffer;
    #endif
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        _device = mtkView.device;
        mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0f);

        // Initialize Rectangles Buffer (part of Arguments Buffer, if enabled)
        {
            //  struct Rectangle
            //  {
            //      float4 color [[id(0)]];
            //      float2 size  [[id(1)]];
            //  };
            MTLArgumentDescriptor* colorArg = [MTLArgumentDescriptor argumentDescriptor];
            colorArg.index = 0;
            colorArg.dataType = MTLDataTypeFloat4;
            colorArg.access = MTLArgumentAccessReadOnly;
            MTLArgumentDescriptor* sizeArg = [MTLArgumentDescriptor argumentDescriptor];
            sizeArg.index = 1;
            sizeArg.dataType = MTLDataTypeFloat2;
            sizeArg.access = MTLArgumentAccessReadOnly;
            
            id<MTLArgumentEncoder> rectEncoder = [_device newArgumentEncoderWithArguments:@[colorArg, sizeArg]];
            
            uint16_t numRects = 2;
            _rectanglesBuffer = [_device newBufferWithLength:rectEncoder.encodedLength * numRects
                                                     options:MTLResourceStorageModeShared];
            _rectanglesBuffer.label = @"Rects Buffer";
            
            const simd_float4 colors[] = {
                {0.0, 1.0, 0.0, 1.0},
                {0.0, 0.0, 1.0, 1.0}
            };
            const simd_float2 sizes[] = {
                {0.75, 0.75},
                {0.5, 0.25}
            };
            for ( NSUInteger i = 0; i < numRects; ++i )
            {
                [rectEncoder setArgumentBuffer:_rectanglesBuffer
                                        offset:rectEncoder.encodedLength * i];
                {
                    *((simd_float4 *)[rectEncoder constantDataAtIndex:0]) = colors[i];
                    *((simd_float2 *)[rectEncoder constantDataAtIndex:1]) = sizes[i];
                }
            }
        }
        
        // Create our render pipeline and argument buffers
        {
            id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
            id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
            id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
            
            #ifdef USE_ARGUMENTS_BUFFER
            {
                //  struct SceneArgumentBuffer {
                //      constant Rectangle *rects [[ id(SceneArgumentBufferIDRectangles) ]];
                //  };
                MTLArgumentDescriptor* rectArg = [MTLArgumentDescriptor argumentDescriptor];
                rectArg.index = SceneArgumentBufferIDRectangles;
                rectArg.dataType = MTLDataTypePointer;
                rectArg.access = MTLArgumentAccessReadOnly;
                
                id<MTLArgumentEncoder> argumentEncoder = [_device newArgumentEncoderWithArguments:@[rectArg]];
                _argumentBuffer = [_device newBufferWithLength:argumentEncoder.encodedLength
                                                       options:MTLResourceStorageModeManaged];
                _argumentBuffer.label = @"Argument Buffer";
                [argumentEncoder setArgumentBuffer:_argumentBuffer
                                            offset:0];
                [argumentEncoder setBuffer:_rectanglesBuffer
                                    offset:0
                                   atIndex:0];
            }
            #endif

            MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipelineStateDescriptor.label = @"Argument Buffer Example";
            pipelineStateDescriptor.vertexFunction = vertexFunction;
            pipelineStateDescriptor.fragmentFunction = fragmentFunction;
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
            pipelineStateDescriptor.vertexBuffers[0].mutability = MTLMutabilityImmutable;
            
            NSError *error;
            _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                     error:&error];
            NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error.localizedDescription);
        }
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if(renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        #ifdef USE_ARGUMENTS_BUFFER
            [renderEncoder useResource:_rectanglesBuffer
                                 usage:MTLResourceUsageRead
                                stages:MTLRenderStageVertex];
        #endif
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:
                                        #ifdef USE_ARGUMENTS_BUFFER
                                            _argumentBuffer
                                        #else
                                            _rectanglesBuffer
                                        #endif
                                offset:0
                               atIndex:VertexBufferIndexArgumentBuffer];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:4
                          instanceCount:2];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {}

@end

