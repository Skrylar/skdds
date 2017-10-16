NOTE: Does not recognize or support volumetric and cube map textures. It will be confused by them and read garbage.

# Querying

`proc base_width*(self: DdsReader): int`

`proc base_height*(self: DdsReader): int`

Returns the *base* width or height of the image file. This does not change with the image's current mipmap level.

`proc width*(self: DdsReader): int`

`proc height*(self: DdsReader): int`

Returns the *current* width or height of the image. As smaller mipmap levels are encountered, this size shrinks progressivey.

`proc current_mipmap*(self: DdsReader): int`

Returns the current mip map encountered in the file, starting at zero.

`proc total_mipmaps*(self: DdsReader): int`

Returns total number of mipmaps in the file.

`proc channel_count*(self: DdsReader): int`

Makes an educated guess at the number of channels within this file. It does this by looking at whether the file is compressed or not, if certain flags are set, or certain FourCC codes are encountered. It may return `-1`, as there is no explicit channel count in a DDS file and unrecognized compression methods leave no way of knowing the proper size.

# Reading
These are the basic procedures for getting your texture data out.

`proc init*(self: var DdsReader; f: File): bool`

Reads the header of a DDS from a file, storing it in the DDS reader. Returns `true` if a valid header could be read.

`proc read*(self: var DdsReader; f: File; destination: var seq[uint8]): bool`

Reads the current surface and/or mipmap level to `destination`, which will be `setLen` to the proper size. Returns `true` if data was read.

NOTE: DDS reader will not *decode* texel information. When reading compressed textures, you will receive the blob of compressed data for shipping to a decoder (or more likely, your GPU.)

`proc skip*(self: var DdsReader; f: File): bool`

Skips the current surface and/or mipmap level. Will seek forward in the file by the size of the image block. Returns `true` if skipping was successful. Skipping fails when the end of file is reached, such as the final mipmap in a mipmapped texture.

