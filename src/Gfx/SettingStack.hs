module Gfx.SettingStack
  ( SettingStack(..)
  , create
  , value
  , reset
  , snapshot
  )
where

import           Lens.Simple                    ( Lens
                                                , lens
                                                )

data SettingStack v = SettingStack
  { stack :: [v]
  , defaultValue :: v
  } deriving (Eq, Show)

create :: k -> SettingStack k
create value = SettingStack { stack = [value], defaultValue = value }

get :: SettingStack k -> k
get setting = case stack setting of
  v : _ -> v
  []    -> defaultValue setting

set :: SettingStack k -> k -> SettingStack k
set setting value = setting { stack = value : stack setting }

value :: Lens (SettingStack v) (SettingStack v) v v
value = lens get set

save :: SettingStack k -> [k]
save setting = stack setting

load :: SettingStack k -> [k] -> SettingStack k
load setting st = setting { stack = st }

snapshot :: Lens (SettingStack v) (SettingStack v) [v] [v]
snapshot = lens save load

reset :: SettingStack k -> SettingStack k
reset setting = setting { stack = [defaultValue setting] }

