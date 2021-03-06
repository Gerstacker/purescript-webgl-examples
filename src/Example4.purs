module Example4 where

import Prelude
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import System.Clock (CLOCK, milliseconds)
import Data.Maybe (Maybe(Just, Nothing))
import Data.Array (concatMap, concat)
import Math (pi)
import Data.Int (toNumber)

import Graphics.WebGLAll (EffWebGL, Buffer, Mat4, Uniform, Vec3, Attribute, WebGLProg, WebGLContext, BufferTarget(ELEMENT_ARRAY_BUFFER), Capacity(DEPTH_TEST), Mask(DEPTH_BUFFER_BIT, COLOR_BUFFER_BIT), Mode(TRIANGLES), Shaders(Shaders), drawElements, bindBuf, bindBufAndSetVertexAttr, setUniformFloats, drawArr, clear, viewport, getCanvasHeight, getCanvasWidth, requestAnimationFrame, enable, clearColor, makeBuffer, makeBufferFloat, withShaders, runWebGL)
import Data.Matrix4 (identity, translate, rotate, makePerspective) as M
import Data.Matrix (toArray) as M
import Data.Vector3 as V3
import Control.Monad.Eff.Alert (Alert, alert)
import Data.ArrayBuffer.Types (Uint16, Float32) as T
import Data.TypedArray (asUint16Array) as T

shaders :: Shaders {aVertexPosition :: Attribute Vec3, aVertexColor :: Attribute Vec3,
                      uPMatrix :: Uniform Mat4, uMVMatrix:: Uniform Mat4}
shaders = Shaders

  """precision mediump float;

  varying vec4 vColor;

  void main(void) {
    gl_FragColor = vColor;
      }
  """

  """
      attribute vec3 aVertexPosition;
      attribute vec4 aVertexColor;

      uniform mat4 uMVMatrix;
      uniform mat4 uPMatrix;

      varying vec4 vColor;

      void main(void) {
          gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
          vColor = aVertexColor;
      }
  """

type State = {
                context :: WebGLContext,
                shaderProgram :: WebGLProg,
                aVertexPosition :: Attribute Vec3,
                aVertexColor  :: Attribute Vec3,
                uPMatrix :: Uniform Mat4,
                uMVMatrix :: Uniform Mat4,
                pyramidVertices ::Buffer T.Float32,
                pyramidColors :: Buffer T.Float32,
                cubeVertices :: Buffer T.Float32,
                cubeColors :: Buffer T.Float32,
                cubeVertexIndices :: Buffer T.Uint16,
                lastTime :: Maybe Number,
                rPyramid :: Number,
                rCube :: Number
              }

main :: Eff (console :: CONSOLE, alert :: Alert, clock :: CLOCK) Unit
main =
  runWebGL
    "glcanvas"
    (\s -> alert s)
      \ context -> do
        log "WebGL started"
        withShaders shaders
                    (\s -> alert s)
                      \ bindings -> do
          pyramidVertices <- makeBufferFloat [
                              -- Front face
                               0.0,  1.0,  0.0,
                              -1.0, -1.0,  1.0,
                               1.0, -1.0,  1.0,

                              -- Right face
                               0.0,  1.0,  0.0,
                               1.0, -1.0,  1.0,
                               1.0, -1.0, -1.0,

                              -- Back face
                               0.0,  1.0,  0.0,
                               1.0, -1.0, -1.0,
                              -1.0, -1.0, -1.0,

                              -- Left face
                               0.0,  1.0,  0.0,
                              -1.0, -1.0, -1.0,
                              -1.0, -1.0,  1.0]
          pyramidColors <- makeBufferFloat   [
                              -- Front face
                              1.0, 0.0, 0.0, 1.0,
                              0.0, 1.0, 0.0, 1.0,
                              0.0, 0.0, 1.0, 1.0,

                              -- Right face
                              1.0, 0.0, 0.0, 1.0,
                              0.0, 0.0, 1.0, 1.0,
                              0.0, 1.0, 0.0, 1.0,

                              -- Back face
                              1.0, 0.0, 0.0, 1.0,
                              0.0, 1.0, 0.0, 1.0,
                              0.0, 0.0, 1.0, 1.0,

                              -- Left face
                              1.0, 0.0, 0.0, 1.0,
                              0.0, 0.0, 1.0, 1.0,
                              0.0, 1.0, 0.0, 1.0]
          cubeVertices <- makeBufferFloat [
                            -- Front face
                            -1.0, -1.0,  1.0,
                             1.0, -1.0,  1.0,
                             1.0,  1.0,  1.0,
                            -1.0,  1.0,  1.0,

                            -- Back face
                            -1.0, -1.0, -1.0,
                            -1.0,  1.0, -1.0,
                             1.0,  1.0, -1.0,
                             1.0, -1.0, -1.0,

                            -- Top face
                            -1.0,  1.0, -1.0,
                            -1.0,  1.0,  1.0,
                             1.0,  1.0,  1.0,
                             1.0,  1.0, -1.0,

                            -- Bottom face
                            -1.0, -1.0, -1.0,
                             1.0, -1.0, -1.0,
                             1.0, -1.0,  1.0,
                            -1.0, -1.0,  1.0,

                            -- Right face
                             1.0, -1.0, -1.0,
                             1.0,  1.0, -1.0,
                             1.0,  1.0,  1.0,
                             1.0, -1.0,  1.0,

                            -- Left face
                            -1.0, -1.0, -1.0,
                            -1.0, -1.0,  1.0,
                            -1.0,  1.0,  1.0,
                            -1.0,  1.0, -1.0]
          cubeColors <- makeBufferFloat $ concat $ concatMap (\e -> [e,e,e,e])
                              [[1.0, 0.0, 0.0, 1.0], -- Front face
                              [1.0, 1.0, 0.0, 1.0], -- Back face
                              [0.0, 1.0, 0.0, 1.0], -- Top face
                              [1.0, 0.5, 0.5, 1.0], -- Bottom face
                              [1.0, 0.0, 1.0, 1.0], -- Right face
                              [0.0, 0.0, 1.0, 1.0]]  -- Left face
          cubeVertexIndices <- makeBuffer ELEMENT_ARRAY_BUFFER T.asUint16Array [
                              0, 1, 2,      0, 2, 3,    -- Front face
                              4, 5, 6,      4, 6, 7,    -- Back face
                              8, 9, 10,     8, 10, 11,  -- Top face
                              12, 13, 14,   12, 14, 15, -- Bottom face
                              16, 17, 18,   16, 18, 19, -- Right face
                              20, 21, 22,   20, 22, 23]  -- Left face]
          clearColor 0.0 0.0 0.0 1.0
          enable DEPTH_TEST
          let state = {
                        context : context,
                        shaderProgram : bindings.webGLProgram,
                        aVertexPosition : bindings.aVertexPosition,
                        aVertexColor : bindings.aVertexColor,
                        uPMatrix : bindings.uPMatrix,
                        uMVMatrix : bindings.uMVMatrix,
                        pyramidVertices : pyramidVertices,
                        pyramidColors : pyramidColors,
                        cubeVertices : cubeVertices,
                        cubeColors : cubeColors,
                        cubeVertexIndices : cubeVertexIndices,
                        lastTime : Nothing,
                        rPyramid : 0.0,
                        rCube : 0.0
                      }
          tick state

tick :: forall eff. State ->  EffWebGL (console :: CONSOLE, clock :: CLOCK |eff) Unit
tick state = do
--  log ("tick: " ++ show state.lastTime)
  drawScene state
  state' <- animate state
  requestAnimationFrame (tick state')

animate ::  forall eff. State -> EffWebGL (clock :: CLOCK |eff) State
animate state = do
  timeNow <- milliseconds
  case state.lastTime of
    Nothing -> pure state {lastTime = Just timeNow}
    Just lastt ->
      let elapsed = timeNow - lastt
      in pure state {lastTime = Just timeNow,
                       rPyramid = state.rPyramid + (90.0 * elapsed) / 1000.0,
                       rCube = state.rCube + (75.0 * elapsed) / 1000.0}

drawScene :: forall eff. State -> EffWebGL (clock :: CLOCK |eff) Unit
drawScene s = do
      canvasWidth <- getCanvasWidth s.context
      canvasHeight <- getCanvasHeight s.context
      viewport 0 0 canvasWidth canvasHeight
      clear [COLOR_BUFFER_BIT, DEPTH_BUFFER_BIT]

-- The pyramid
      let pMatrix = M.makePerspective 45.0 (toNumber canvasWidth / toNumber canvasHeight) 0.1 100.0
      setUniformFloats s.uPMatrix (M.toArray pMatrix)
      let mvMatrix = M.rotate (degToRad s.rPyramid) (V3.vec3' [0.0, 1.0, 0.0])
                        $ M.translate  (V3.vec3 (-1.5) 0.0 (-8.0))
                          $ M.identity

      setUniformFloats s.uMVMatrix (M.toArray mvMatrix)
      bindBufAndSetVertexAttr s.pyramidColors s.aVertexColor
      drawArr TRIANGLES s.pyramidVertices s.aVertexPosition

-- The cube
      let mvMatrix' = M.rotate (degToRad s.rCube) (V3.vec3' [1.0, 1.0, 1.0])
                        $ M.translate  (V3.vec3 (1.5) 0.0 (-8.0))
                          $ M.identity
      setUniformFloats s.uMVMatrix (M.toArray mvMatrix')

      bindBufAndSetVertexAttr s.cubeColors s.aVertexColor
      bindBufAndSetVertexAttr s.cubeVertices s.aVertexPosition
      bindBuf s.cubeVertexIndices
      drawElements TRIANGLES s.cubeVertexIndices.bufferSize


-- | Convert from radians to degrees.
radToDeg :: Number -> Number
radToDeg x = x/pi*180.0

-- | Convert from degrees to radians.
degToRad :: Number -> Number
degToRad x = x/180.0*pi
