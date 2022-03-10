# XCode Crash with Metal Arguments Buffer Repro

Attempting to use an Arguments Buffer (`SceneArgumentBuffer`) containing a pointer (array) of `Rectangle` causes XCode Frame Capture to crash.

```
Crashed Thread:        24  Dispatch queue: gputools.GPUMTLVariablesViewContentProvider.0x2d0638a40

Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
Exception Codes:       KERN_INVALID_ADDRESS at 0x0000000000000a10
Exception Codes:       0x0000000000000001, 0x0000000000000a10
Exception Note:        EXC_CORPSE_NOTIFY
```

## Snippets of Arguments Buffer usage

### Common code

```c++
// File: AAPLShaderTypes.h
// -----------------------
typedef struct Rectangle
{
    vector_float4 color;
    vector_float2 size;
} Rectangle;

```

### Vertex Shader code

```c++
// File: AAPLShaders.metal
// -----------------------
struct SceneArgumentBuffer {
    device Rectangle *rects [[ id(SceneArgumentBufferIDRectangles) ]];
};

vertex VertexOut
vertexShader(         uint                 instanceID [[ instance_id ]],
                      uint                 vertexID   [[ vertex_id ]],
             constant SceneArgumentBuffer &args       [[ buffer(VertexBufferIndexArgumentBuffer) ]])
{
    // ...
}
```

### Renderer code

```obj-c
// File: AAPLShaderTypes.h
// -----------------------

// Nested buffer (Array of Rectangle structs)
uint16_t numRects = 2;
_rectanglesBuffer = [_device newBufferWithLength:sizeof(Rectangle) * numRects
                                            options:MTLResourceStorageModeShared];
_rectanglesBuffer.label = @"Rects Buffer";

Rectangle * const rects = _rectanglesBuffer.contents;
rects[0].color = simd_make_float4(0.0, 1.0, 0.0, 1.0);
rects[0].size  = simd_make_float2(0.75, 0.75);

rects[1].color = simd_make_float4(0.0, 0.0, 1.0, 1.0);
rects[1].size  = simd_make_float2(0.5, 0.25);

// Argument buffer creation and encoding
id<MTLArgumentEncoder> argumentEncoder =
    [vertexFunction newArgumentEncoderWithBufferIndex:VertexBufferIndexArgumentBuffer];
_argumentBuffer = [_device newBufferWithLength:argumentEncoder.encodedLength options:0];
_argumentBuffer.label = @"Argument Buffer";
[argumentEncoder setArgumentBuffer:_argumentBuffer
                            offset:0];
[argumentEncoder setBuffer:_rectanglesBuffer
                    offset:0
                    atIndex:SceneArgumentBufferIDRectangles];

// Encoding into a Render Command
id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
[renderEncoder useResource:_rectanglesBuffer
                     usage:MTLResourceUsageRead
                    stages:MTLRenderStageVertex];
[renderEncoder setVertexBuffer:_argumentBuffer
                        offset:0
                       atIndex:VertexBufferIndexArgumentBuffer];
```

# Reproduction Steps

1. git clone this repository
    > git clone git@github.com:peterwmwong/ArgumentBufferXCodeCrashRepro.git
1. Open project in XCode
1. Update Project settings to assign team
    - "Signing & Capabilities" -> "Signing" -> "Team"
1. Build / Run
1. Verify application window appears and 2 overlapping rectangles appear (green and blue).
1. In XCode, Capture GPU Workload
1. In the Debug navigator sidebar, navigate and select the only draw render command
    - MyCommand -> MyRenderEncoder -> [drawPrimitives: ...]
1. Notice XCode crashes with a similar looking report...
    ```
    Process:               Xcode [28558]
    Path:                  /Applications/Xcode.app/Contents/MacOS/Xcode
    Identifier:            com.apple.dt.Xcode
    Version:               13.2 (19585)
    Build Info:            IDEFrameworks-19585000000000000~2 (13C90)
    Code Type:             ARM-64 (Native)
    Parent Process:        launchd [1]
    User ID:               501

    Date/Time:             2022-03-10 12:33:57.8934 -0600
    OS Version:            macOS 12.2.1 (21D62)
    Report Version:        12
    Anonymous UUID:        9B84779D-936D-99F7-788A-C88BA5F20B46

    Sleep/Wake UUID:       E0F868C8-9471-44EF-9B92-B523178F0A9C

    Time Awake Since Boot: 33000 seconds
    Time Since Wake:       7694 seconds

    System Integrity Protection: enabled

    Crashed Thread:        24  Dispatch queue: gputools.GPUMTLVariablesViewContentProvider.0x2d0638a40

    Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
    Exception Codes:       KERN_INVALID_ADDRESS at 0x0000000000000a10
    Exception Codes:       0x0000000000000001, 0x0000000000000a10
    Exception Note:        EXC_CORPSE_NOTIFY

    Termination Reason:    Namespace SIGNAL, Code 11 Segmentation fault: 11
    Terminating Process:   exc handler [28558]

    VM Region Info: 0xa10 is not in any region.  Bytes before following region: 4374443504
        REGION TYPE                    START - END         [ VSIZE] PRT/MAX SHRMOD  REGION DETAIL
        UNUSED SPACE AT START
    --->  
        __TEXT                      104bcc000-104bd0000    [   16K] r-x/r-x SM=COW  ...s/MacOS/Xcode
    ```

## Screen recordings

### Using Arguments Buffer (crash)

![Using Arguments Buffer with XCode crash](./enabled-arguments-buffer.gif)
[MOV video](./enabled-arguments-buffer.mov)

### NOT using Arguments Buffer (no crash)

![NOT using Arguments Buffer](./disabled-arguments-buffer.gif)
[MOV video](./disabled-arguments-buffer.mov)

## Enable/Disable using Arguments Buffer

- Open `AAPLShaderTypes.h`
- Enable using Arguments Buffer...
    ```c++
    #define USE_ARGUMENTS_BUFFER
    //#undef USE_ARGUMENTS_BUFFER
    ```
- Disable using Arguments Buffer...
    ```c++
    //#define USE_ARGUMENTS_BUFFER
    #undef USE_ARGUMENTS_BUFFER
    ```