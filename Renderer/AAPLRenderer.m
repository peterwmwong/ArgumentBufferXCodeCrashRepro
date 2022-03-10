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
            uint16_t numRects = 2;
            _rectanglesBuffer = [_device newBufferWithLength:sizeof(Rectangle) * numRects
                                                     options:MTLResourceStorageModeShared];
            _rectanglesBuffer.label = @"Rects Buffer";
            
            Rectangle * const rects = _rectanglesBuffer.contents;
            rects[0].color = simd_make_float4(0.0, 1.0, 0.0, 1.0);
            rects[0].size  = simd_make_float2(0.75, 0.75);
            
            rects[1].color = simd_make_float4(0.0, 0.0, 1.0, 1.0);
            rects[1].size  = simd_make_float2(0.5, 0.25);
        }
        
        // Create our render pipeline and argument buffers
        {
            id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
            id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
            id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

            #ifdef USE_ARGUMENTS_BUFFER
            {
                id<MTLArgumentEncoder> argumentEncoder =
                    [vertexFunction newArgumentEncoderWithBufferIndex:VertexBufferIndexArgumentBuffer];
                _argumentBuffer = [_device newBufferWithLength:argumentEncoder.encodedLength options:0];
                _argumentBuffer.label = @"Argument Buffer";

                [argumentEncoder setArgumentBuffer:_argumentBuffer
                                            offset:0];
                [argumentEncoder setBuffer:_rectanglesBuffer
                                    offset:0
                                   atIndex:SceneArgumentBufferIDRectangles];
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

