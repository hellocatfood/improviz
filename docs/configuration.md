# Configuration

Some configuration can be set via command line flags with those and further options also being configurable through a file.

By default, Improviz will attempt to load the *improviz.yaml* file in the same directory it's run from. This file can be changed by using the `-c <filepath>` command line option.

## Screen size

Command line arguments are used to specify the size of the screen with default being 640px wide by 480px high. This can be changed using the `-w` and `-h` command line flags.

```bash
stack exec improviz -- -w 1024 -h 768
```

The `--` in the above is to make it clear to the *stack* tool that these arguments are for the improviz executable.

These can also be set by the *screenwidth* and *screenheight* keys in the confifg file.

```yaml
screenwidth: 1024
screenheight: 768
```

## Full Screen

When making Improviz fullscreen, it's also necessary to pass in the number of the display it should be on.

```bash
stack exec improviz -- -f 0
```

Zero is the primary display. One would be the next attached display to the machine.

This can also be set by the *fillscreen* key in the confifg file.

```yaml
fullscreen: 0
```

## Font File

The font used by default is arial. An alternative can be used by specifying a path to the true text file in the config file.

```yaml
fontfile: /opt/fonts/ComicSans.ttf
```

## Texture Directories

Improviz can be given a list of directories to read texture files from. The details of how this works can be found in [textures.md](textures.md)

```yaml
textureDirectories:
 - /opt/improviz/textures
 - textures
 - ./downloads/textures
```

## Debug

The debug setting can be turned on via the cli or the config file.

```bash
stack exec improviz -- -d
```

```yaml
debug: true
```
