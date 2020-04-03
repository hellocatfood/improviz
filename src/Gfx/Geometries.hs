{-# LANGUAGE OverloadedStrings #-}

module Gfx.Geometries
  ( Geometries
  , GeometryData(..)
  , createAllGeometries
  )
where

import qualified Data.Vector                   as V
import qualified Data.List                     as L
import qualified Data.Map.Strict               as M
import           Data.Maybe                     ( catMaybes )
import           Data.Vector                    ( (!?) )
import           System.FilePath.Posix          ( (</>) )

import           Graphics.Rendering.OpenGL      ( Vertex2(..)
                                                , GLfloat
                                                , Vertex3(..)
                                                )
import           Codec.Wavefront                ( WavefrontOBJ(..)
                                                , Element(..)
                                                , Face(..)
                                                , FaceIndex(..)
                                                , Location(..)
                                                , TexCoord(..)
                                                , fromFile
                                                )

import           Gfx.VertexDataBuffer           ( VertexDataBuffer )
import qualified Gfx.VertexDataBuffer          as VDB
import           Configuration                  ( loadFolderConfig )
import           Configuration.Geometries
import           Logging                        ( logError
                                                , logInfo
                                                )

data GeometryData = GeometryData { positionVerts :: VertexDataBuffer
                                 , textureCoords :: VertexDataBuffer
                                 } deriving (Show, Eq)

type Geometries = M.Map String GeometryData

loc2Vert3 :: Location -> Vertex3 GLfloat
loc2Vert3 (Location x y z _) = Vertex3 x y z

tex2Vert2 :: TexCoord -> Vertex2 GLfloat
tex2Vert2 (TexCoord x y _) = Vertex2 x y

defaultTextureCoords :: Int -> [Vertex2 GLfloat]
defaultTextureCoords num = take num $ L.cycle
  [Vertex2 1 1, Vertex2 0 1, Vertex2 0 0, Vertex2 0 0, Vertex2 1 0, Vertex2 1 1]

objFaceVerts :: WavefrontOBJ -> Maybe [Vertex3 GLfloat]
objFaceVerts obj =
  let verts   = objLocations obj
      locList = V.toList $ faceToVerts verts <$> objFaces obj
  in  L.concat <$> sequence locList
 where
  faceToVerts vertList element = do
    let (Face xIdx yIdx zIdx _) = elValue element
    x <- vertList !? (faceLocIndex xIdx - 1)
    y <- vertList !? (faceLocIndex yIdx - 1)
    z <- vertList !? (faceLocIndex zIdx - 1)
    return [loc2Vert3 x, loc2Vert3 y, loc2Vert3 z]

objTextureCoords :: WavefrontOBJ -> Maybe [Vertex2 GLfloat]
objTextureCoords obj =
  let textCoords = objTexCoords obj
      locList    = V.toList $ faceToVerts textCoords <$> objFaces obj
  in  L.concat <$> sequence locList
 where
  faceToVerts vertList element = do
    let (Face xIdx yIdx zIdx _) = elValue element
    xCoordIdx <- faceTexCoordIndex xIdx
    x         <- vertList !? (xCoordIdx - 1)
    yCoordIdx <- faceTexCoordIndex yIdx
    y         <- vertList !? (yCoordIdx - 1)
    zCoordIdx <- faceTexCoordIndex zIdx
    z         <- vertList !? (zCoordIdx - 1)
    return [tex2Vert2 x, tex2Vert2 y, tex2Vert2 z]

createGeometryData
  :: FilePath -> GeometryConfig -> IO (Maybe (String, GeometryData))
createGeometryData folderPath cfg = do
  fileInput <- fromFile $ folderPath </> geometryFile cfg
  case fileInput of
    Left  err -> logError err >> return Nothing
    Right obj -> case (objFaceVerts obj, objTextureCoords obj) of
      (Just verts, Just texCoords) -> do
        geoData <- GeometryData <$> VDB.create verts <*> VDB.create texCoords
        return $ Just (geometryName cfg, geoData)
      (Just verts, Nothing) -> do
        geoData <- GeometryData <$> VDB.create verts <*> VDB.create
          (defaultTextureCoords (3 * L.length verts))
        return $ Just (geometryName cfg, geoData)
      _ -> return Nothing


loadGeometryFolder :: FilePath -> IO [Maybe (String, GeometryData)]
loadGeometryFolder folderPath = do
  folderConfig <- loadFolderConfig folderPath
  case folderConfig of
    Left  err -> logError err >> return []
    Right cfg -> mapM (createGeometryData folderPath) (geometries cfg)

createAllGeometries :: [FilePath] -> IO Geometries
createAllGeometries folders = do
  geometries <- catMaybes . concat <$> mapM loadGeometryFolder folders
  logInfo $ "Loaded " ++ show (length geometries) ++ " geometry files"
  return $ M.fromList geometries
