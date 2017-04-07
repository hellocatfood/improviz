module Gfx.PostProcessing where

import Graphics.Rendering.OpenGL as GL

import Foreign.Marshal.Array
import Foreign.Storable
import Foreign.Ptr

import Gfx.LoadShaders
import Gfx.GeometryBuffers

data AnimationStyle = NormalStyle | MotionBlur | PaintOver deriving (Eq, Show)

data PostProcessing = PostProcessing {
  input :: Savebuffer,
  motionBlur :: Mixbuffer,
  paintOver :: Mixbuffer,
  output :: Savebuffer
}

instance Show PostProcessing where
  show _ = "PostProcessing"


-- Simple Framebuffer with a texture that can be rendered to and then drawn out to a quad
data Savebuffer = Savebuffer FramebufferObject TextureObject TextureObject Program VBO
data Mixbuffer = Mixbuffer FramebufferObject TextureObject TextureObject Program VBO

-- 2D positions and texture coordinates
quadVertices :: [GLfloat]
quadVertices = [
    -1,  1, 0, 0,  1,
    -1, -1, 0, 0,  0,
     1,  1, 0, 1,  1,

     1,  1, 0, 1,  1,
    -1, -1, 0, 0,  0,
     1, -1, 0, 1,  0
  ]

quadVBO :: IO VBO
quadVBO = do
  vbo <- genObjectName
  bindVertexArrayObject $= Just vbo
  arrayBuffer <- genObjectName
  bindBuffer ArrayBuffer $= Just arrayBuffer
  let
    vertexSize = sizeOf (head quadVertices)
    firstPosIndex = 0
    firstTexIndex = 3 * vertexSize
    vPosition = AttribLocation 0
    vTexCoord = AttribLocation 1
    numVertices = length quadVertices
    size = fromIntegral (numVertices * vertexSize)
    stride = fromIntegral (5 * vertexSize)
  withArray quadVertices $ \ptr ->
    bufferData ArrayBuffer $= (size, ptr, StaticDraw)
  vertexAttribPointer vPosition $= (ToFloat, VertexArrayDescriptor 3 Float stride (bufferOffset firstPosIndex))
  vertexAttribPointer vTexCoord $= (ToFloat, VertexArrayDescriptor 2 Float stride (bufferOffset firstTexIndex))
  vertexAttribArray vPosition $= Enabled
  vertexAttribArray vTexCoord $= Enabled
  return $ VBO vbo firstPosIndex 6


create2DTexture :: GLint -> GLint -> IO TextureObject
create2DTexture width height = do
  text <- genObjectName
  textureBinding Texture2D $= Just text
  GL.textureFilter GL.Texture2D $= ((GL.Linear', Nothing), GL.Linear')
  let pd = PixelData RGB UnsignedByte nullPtr
  texImage2D Texture2D NoProxy 0 RGB' (TextureSize2D width height) 0 pd
  textureBinding Texture2D $= Nothing
  return text

createDepthbuffer :: GLint -> GLint -> IO TextureObject
createDepthbuffer width height = do
  depth <- genObjectName
  textureBinding Texture2D $= Just depth
  GL.textureFilter GL.Texture2D $= ((GL.Linear', Nothing), GL.Linear')
  let pd = PixelData DepthComponent UnsignedByte nullPtr
  texImage2D Texture2D NoProxy 0 DepthComponent24 (TextureSize2D width height) 0 pd
  framebufferTexture2D Framebuffer DepthAttachment Texture2D depth 0
  textureBinding Texture2D $= Nothing
  return depth

createPostProcessing :: GLint -> GLint -> IO PostProcessing
createPostProcessing width height = do
  inputBuffer <- createSavebuffer width height
  motionBlurBuffer <- createMotionBlurbuffer width height
  paintOverBuffer <- createPaintOverbuffer width height
  outputBuffer <- createSavebuffer width height
  return $ PostProcessing inputBuffer motionBlurBuffer paintOverBuffer outputBuffer


createSavebuffer :: GLint -> GLint -> IO Savebuffer
createSavebuffer width height = do
  fbo <- genObjectName
  bindFramebuffer Framebuffer $= fbo

  text <- create2DTexture width height
  framebufferTexture2D Framebuffer (ColorAttachment 0) Texture2D text 0

  depth <- createDepthbuffer width height

  qvbo <- quadVBO
  program <- loadShaders [
    ShaderInfo VertexShader (FileSource "shaders/savebuffer.vert"),
    ShaderInfo FragmentShader (FileSource "shaders/savebuffer.frag")]

  return $ Savebuffer fbo text depth program qvbo

createMotionBlurbuffer :: GLint -> GLint -> IO Mixbuffer
createMotionBlurbuffer width height = do
  fbo <- genObjectName
  bindFramebuffer Framebuffer $= fbo

  text <- create2DTexture width height
  framebufferTexture2D Framebuffer (ColorAttachment 0) Texture2D text 0

  depth <- createDepthbuffer width height

  qvbo <- quadVBO
  program <- loadShaders [
    ShaderInfo VertexShader (FileSource "shaders/motionBlur.vert"),
    ShaderInfo FragmentShader (FileSource "shaders/motionBlur.frag")]

  return $ Mixbuffer fbo text depth program qvbo


createPaintOverbuffer :: GLint -> GLint -> IO Mixbuffer
createPaintOverbuffer width height = do
  fbo <- genObjectName
  bindFramebuffer Framebuffer $= fbo

  text <- create2DTexture width height
  framebufferTexture2D Framebuffer (ColorAttachment 0) Texture2D text 0

  depth <- createDepthbuffer width height

  qvbo <- quadVBO
  program <- loadShaders [
    ShaderInfo VertexShader (FileSource "shaders/paintOver.vert"),
    ShaderInfo FragmentShader (FileSource "shaders/paintOver.frag")]

  return $ Mixbuffer fbo text depth program qvbo


usePostProcessing :: PostProcessing -> IO ()
usePostProcessing post = do
  let (Savebuffer fbo _ _ _ _) = input post
  bindFramebuffer Framebuffer $= fbo

renderPostProcessing :: PostProcessing -> AnimationStyle -> IO ()
renderPostProcessing post animStyle = do
  depthFunc $= Nothing
  case animStyle of
    NormalStyle -> do
      bindFramebuffer Framebuffer $= defaultFramebufferObject
      renderSavebuffer $ input post
    MotionBlur -> do
      let (Savebuffer _ sceneFrame sceneDepth _ _) = input post
      let outbuffer@(Savebuffer outFBO previousFrame _ _ _) = output post
      bindFramebuffer Framebuffer $= outFBO
      renderMotionBlurbuffer (motionBlur post) sceneFrame previousFrame 0.7
      bindFramebuffer Framebuffer $= defaultFramebufferObject
      renderSavebuffer outbuffer
    PaintOver -> do
      let (Savebuffer _ sceneFrame sceneDepth _ _) = input post
      let outbuffer@(Savebuffer outFBO previousFrame _ _ _) = output post
      bindFramebuffer Framebuffer $= outFBO
      renderPaintOverbuffer (paintOver post) sceneDepth sceneFrame previousFrame
      bindFramebuffer Framebuffer $= defaultFramebufferObject
      renderSavebuffer outbuffer

renderSavebuffer :: Savebuffer -> IO ()
renderSavebuffer (Savebuffer _ text _ program quadVBO) = do
  currentProgram $= Just program
  activeTexture $= TextureUnit 0
  textureBinding Texture2D $= Just text
  let (VBO qbo qbai qbn) = quadVBO
  bindVertexArrayObject $= Just qbo
  drawArrays Triangles qbai qbn

renderMotionBlurbuffer :: Mixbuffer -> TextureObject -> TextureObject -> GLfloat -> IO ()
renderMotionBlurbuffer (Mixbuffer _ _ _ program quadVBO) nextFrame lastFrame mix = do
  activeTexture $= TextureUnit 0
  textureBinding Texture2D $= Just nextFrame
  activeTexture $= TextureUnit 1
  textureBinding Texture2D $= Just lastFrame

  currentProgram $= Just program

  texFramebufferU <- GL.get $ uniformLocation program "texFramebuffer"
  lastFrameU <- GL.get $ uniformLocation program "lastFrame"
  mixRatioU <- GL.get $ uniformLocation program "mixRatio"


  uniform texFramebufferU $= TextureUnit 0
  uniform lastFrameU $= TextureUnit 1
  uniform mixRatioU $= mix

  let (VBO qbo qbai qbn) = quadVBO
  bindVertexArrayObject $= Just qbo
  drawArrays Triangles qbai qbn

renderPaintOverbuffer :: Mixbuffer -> TextureObject -> TextureObject -> TextureObject -> IO ()
renderPaintOverbuffer (Mixbuffer _ _ _ program quadVBO) depth nextFrame lastFrame = do
  activeTexture $= TextureUnit 0
  textureBinding Texture2D $= Just nextFrame
  activeTexture $= TextureUnit 1
  textureBinding Texture2D $= Just lastFrame
  activeTexture $= TextureUnit 2
  textureBinding Texture2D $= Just depth

  currentProgram $= Just program

  texFramebufferU <- GL.get $ uniformLocation program "texFramebuffer"
  lastFrameU <- GL.get $ uniformLocation program "lastFrame"
  depthU <- GL.get $ uniformLocation program "depth"


  uniform texFramebufferU $= TextureUnit 0
  uniform lastFrameU $= TextureUnit 1
  uniform depthU $= TextureUnit 2

  let (VBO qbo qbai qbn) = quadVBO
  bindVertexArrayObject $= Just qbo
  drawArrays Triangles qbai qbn

