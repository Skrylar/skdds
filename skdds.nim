
import math

template make_fourcc(a, b, c, d: char): uint32 =
  (d.uint32 shl 24).uint32 + (c.uint32 shl 16).uint32 + (b.uint32 shl 8).uint32 + a.uint32

const
  DdsMagic* = make_fourcc('D', 'D', 'S', ' ')

type
  DdsFourCC* = distinct uint32
const
  fccBc5* = make_fourcc('A', '2', 'X', 'Y').DdsFourCC ## XY compression; for normal maps, where the Z is discarded and X/Y are encoded independently.
  fccDx10* = make_fourcc('D', 'X', '1', '0').DdsFourCC ## Is a newer, DX10 version of the DDS format.
  fccDxt1* = make_fourcc('D', 'X', 'T', '1').DdsFourCC ## RGB compression, with optional bitonal alpha channels.
  fccDxt2* = make_fourcc('D', 'X', 'T', '2').DdsFourCC ## RGBA compression, premultiplied by alpha. Explicit alpha channels.
  fccDxt3* = make_fourcc('D', 'X', 'T', '3').DdsFourCC ## RGBA compression, which is NOT premultiplied. Explicit alpha channels.
  fccDxt4* = make_fourcc('D', 'X', 'T', '4').DdsFourCC ## RGBA compression, premultiplied by alpha. Implicit alpha channels.
  fccDxt5* = make_fourcc('D', 'X', 'T', '5').DdsFourCC ## RGBA compression, which is NOT premultiplied. Implicit alpha channels.

template `==`*(a, b: DdsFourCC): bool =
  a.uint32 == b.uint32

type
  DdsPixelFormatFlag* = enum
    DDPF_ALPHA_PIXELS = 0x1 ## Texture includes an alpha channel.
    DDPF_ALPHA        = 0x2 ## Only alpha information is present.
    DDPF_FOURCC       = 0x4 ## Compressed data present, check fourcc field.
    DDPF_RGB          = 0x40 ## Uncompressed RGB data is in this file.
    DDPF_YUV          = 0x200 ## Indicates the DDS file contains uncompressed YUV data, instead of RGB.
    DDPF_LUMINANCE    = 0x20000 ## Indicates a single channel file (dual channel if alpha pixels is also set.)

  RawDdsPixelFormat* = object
    size*: uint32 ## Size of the structure.
    flags*: uint32
    fourcc*: uint32
    rgb_bit_count*: uint32
    r_bit_mask*: uint32
    g_bit_mask*: uint32
    b_bit_mask*: uint32
    a_bit_mask*: uint32

  DdsFlags* = enum
    DDSD_CAPS          = 0x1
    DDSD_HEIGHT        = 0x2
    DDSD_WIDTH         = 0x4
    DDSD_PITCH         = 0x8 ## Indicates the texture is uncompressed, and has a pitch value.
    DDSD_PIXELFORMAT   = 0x1000
    DDSD_MIP_MAP_COUNT = 0x20000 ## Indicates mipmaps are present.
    DDSD_LINEAR_SIZE   = 0x80000 ## Indicates the size of a compressed image is present, within the pitch field.
    DDSD_DEPTH         = 0x800000 ## Indicates volume depth is present.

  DdsCaps* = enum
    DDSCAPS_COMPLEX = 0x8 ## DDS has more than one surface inside.
    DDSCAPS_TEXTURE = 0x1000
    DDSCAPS_MIPMAP  = 0x400000 ## Indicates a mipmap is present.

  DdsCaps2* = enum
    DDSCAPS2_CUBEMAP           = 0x200
    DDSCAPS2_CUBEMAP_POSITIVEX = 0x400
    DDSCAPS2_CUBEMAP_NEGATIVEX = 0x800
    DDSCAPS2_CUBEMAP_POSITIVEY = 0x1000
    DDSCAPS2_CUBEMAP_NEGATIVEY = 0x2000
    DDSCAPS2_CUBEMAP_POSITIVEZ = 0x4000
    DDSCAPS2_CUBEMAP_NEGATIVEZ = 0x8000
    DDSCAPS2_VOLUME            = 0x200000

  RawDdsHeader* = object
    size*: uint32 ## Size of header object.
    flags*: uint32 ## Indicates which header fields are set.
    height*, width*: uint32 ## Sizes of the texture.
    pitch_or_linear_size*: uint32 ## Length of a scanline (uncompressed), or total size of compressed texture (compressed.)
    depth*: uint32 ## Depth of a volume texture.
    mip_map_count*: uint32 ## Number of mipmap levels.
    reserved1: array[0..10, uint32]
    pixelformat*: RawDdsPixelFormat
    caps: uint32 ## Capability flags for the DDS file.
    caps2: uint32 ## More capability flags for the DDS file.
    unused_caps: array[0..1, uint32]
    reserved2: uint32

template contains*(format: RawDdsPixelFormat; fcc: DdsFourCC): bool =
  ## Type-safe way to check if format matches a FourCC code.
  format.fourcc == fcc.uint32

template contains*(format: RawDdsPixelFormat; flag: DdsPixelFormatFlag): bool =
  ## Type-safe way to check if a format flag is in a pixel format.
  (flag.ord.uint32 and format.flags) != 0

template contains*(format: RawDdsPixelFormat; flag: DdsCaps): bool =
  ## Type-safe way to check if a cap flag is in a pixel format.
  (flag.ord.uint32 and format.caps) != 0

template contains*(format: RawDdsPixelFormat; flag: DdsCaps2): bool =
  ## Type-safe way to check if a cap flag is in a pixel format.
  (flag.ord.uint32 and format.caps2) != 0

template contains*(header: RawDdsHeader; flag: DdsFlags): bool =
  ## Type-safe way to check if a flag is in a header.
  (flag.ord.uint32 and header.flags) != 0

template contains*(header: RawDdsHeader; flag: DdsCaps): bool =
  ## Type-safe way to check if a cap flag is in a header.
  (flag.ord.uint32 and header.caps) != 0

template contains*(header: RawDdsHeader; flag: DdsCaps2): bool =
  ## Type-safe way to check if a cap flag is in a header.
  (flag.ord.uint32 and header.caps2) != 0

type
  DdsReader* = object
    header: RawDdsHeader
    width, height: int
    current_mip: int

proc init*(self: var DdsReader; f: File): bool =
  result = true
  var magic: uint32

  # read magic number
  if f.readbuffer(cast[pointer](addr magic), 4) != 4:
    return false
  if magic != DdsMagic:
    return false

  # read header
  if f.readbuffer(cast[pointer](addr self.header), RawDdsHeader.sizeof) != RawDdsHeader.sizeof:
    return false
  if self.header.size != RawDdsHeader.sizeof.uint32:
    return false

  # reset current mipmap position
  self.current_mip = 0
  self.width = self.header.width.int
  self.height = self.header.height.int

  # we COULD support these, but it requires calculating the size of
  # compressed images with wierd shapes. GPUs don't like those weird
  # shapes too much, so you shouldn't be using it anyway.
  if not is_power_of_two(self.width):
    return false
  if not is_power_of_two(self.height):
    return false

  # why are you using dds to store uncompressed textures? maybe this
  # will be supported someday but i have better formats for that right
  # now
  var supported = false
  for code in [fccDxt1, fccDxt2, fccDxt3, fccDxt4, fccDxt5, fccBc5]:
    if code in self.header.pixelformat:
      supported = true
      break

  return supported

proc base_width*(self: DdsReader): int {.inline.} =
  ## Returns width of the texture, at the zeroeth mipmap level.
  result = self.header.width.int

proc base_height*(self: DdsReader): int {.inline.} =
  ## Returns width of the texture, at the zeroeth mipmap level.
  result = self.header.height.int

proc size*(self: DdsReader): int =
  # XXX doesn't work if texture sizes aren't powers of two, but we
  # currently reject those kinds of textures. If they are accepted, this
  # needs to calculate the actual size.

  # XXX only true for compressed formats
  let m = if fccDxt1 in self.header.pixelformat: 8 else: 16

  max(self.header.pitch_or_linear_size.int shr (self.current_mip shl 1), m)

proc width*(self: DdsReader): int {.inline.} =
  ## Returns width of the texture, at the current mipmap level.
  result = self.width

proc height*(self: DdsReader): int {.inline.} =
  ## Returns width of the texture, at the current mipmap level.
  result = self.height

proc current_mipmap*(self: DdsReader): int {.inline.} =
  ## Returns the index of the current mipmap, starting from zero.
  result = self.current_mip

proc total_mipmaps*(self: DdsReader): int =
  ## Returns the total number of mipmaps in this image, starting from
  ## zero.
  if DDSD_MIP_MAP_COUNT in self.header:
    return self.header.mip_map_count.int
  else:
    return 0

proc channel_count*(self: DdsReader): int =
  ## Calculates the number of color channels which exist in this
  ## surface.
  if DDPF_LUMINANCE in self.header.pixelformat:
    if DDPF_ALPHA_PIXELS in self.header.pixelformat:
      return 2
    else:
      return 1
  elif DDPF_ALPHA in self.header.pixelformat:
    return 1
  elif (DDPF_RGB in self.header.pixelformat) or (DDPF_YUV in self.header.pixelformat):
    if DDPF_ALPHA_PIXELS in self.header.pixelformat:
      return 4
    else:
      return 3
  elif DDPF_FOURCC in self.header.pixelformat:
    # let us begin hating ourselves
    if fccBc5 in self.header.pixelformat:
      return 2
    else:
      # this is statistically the correct answer
      if DDPF_ALPHA_PIXELS in self.header.pixelformat:
        return 4
      else:
        return 3
  else:
    # Considering we covered all the legal possibilities, the file is
    # broken.
    return -1

template complete_mip_stage(self: var DdsReader) =
  # increment mip level
  inc self.current_mip
  self.width = self.width shr 1
  self.height = self.height shr 1

proc skip*(self: var DdsReader; f: File): bool =
  ## Skips the current mip-map, moving on to the next if possible.
  ## Returns false when there is no more image to navigate.
  result = true
  if self.current_mip >= self.total_mipmaps:
    return false

  # seek forward
  f.set_file_pos self.size, fspCur

  self.complete_mip_stage

proc read*(self: var DdsReader; f: File; destination: var seq[uint8]): bool =
  result = true

  # we only recognize some compressed formats as they are easiest to
  # read XXX reading uncompressed formats requires calculating channel
  # count, comparing it to the pitch value, and correctively reading
  # scanlines and skipping bytes outside the pitch to get a valid image;
  # compressed images are just blobs of data that go directly to the
  # GPU.
  var supported = false
  for code in [fccDxt1, fccDxt2, fccDxt3, fccDxt4, fccDxt5, fccBc5]:
    if code in self.header.pixelformat:
      supported = true
      break
  if not supported: return false

  # reserve space for reading
  let s = self.size
  setLen(destination, s)
  if destination.len < s:
    setLen(destination, 0)
    return false

  # perform the read
  let amtread = f.readbuffer(cast[pointer](addr destination[0]), s)
  if amtread < s:
    return false

  self.complete_mip_stage

when isMainModule:
  import unittest

  test "Structure Equivalency":
    assert RawDdsPixelFormat.sizeof == 32
    assert RawDdsHeader.sizeof == 124

  suite "DXT1, mipmapped":
    test "Headers":
      var f: File
      var dds: DdsReader

      check f.open("test/lenna-mipmap-dxt1.dds", fmRead) == true
      check dds.init(f) == true
      check dds.base_width == 512
      check dds.base_height == 512
      require dds.total_mipmaps > 0
      check dds.channel_count == 3

      for m in 0..dds.total_mipmaps-1:
        require dds.skip(f) == true

      require dds.skip(f) == false

    test "Dumping Bytes":
      var f: File
      var dds: DdsReader
      var bytes: seq[uint8]
      newSeq(bytes, 0)

      check f.open("test/lenna-mipmap-dxt1.dds", fmRead) == true
      check dds.init(f) == true
      check dds.base_width == 512
      check dds.base_height == 512
      require dds.total_mipmaps > 0
      check dds.channel_count == 3

      for m in 0..dds.total_mipmaps-1:
        require dds.read(f, bytes) == true

      require dds.skip(f) == false

  suite "DXT1, no mipmap":
    test "Headers":
      var f: File
      var dds: DdsReader

      check f.open("test/lenna-nomipmap-dxt1.dds", fmRead) == true
      check dds.init(f) == true
      check dds.base_width == 512
      check dds.base_height == 512
      check dds.total_mipmaps == 0
      check dds.channel_count == 3

      check dds.skip(f) == false
