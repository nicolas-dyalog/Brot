:Namespace Png
    ⎕IO ⎕ML←1 1

    ⍝ Main entry points

    ∇ uri←Uri pixmat;depth;png              
    ⍝ export image as a self-contained URI
      depth←24 32[1+16777215<⌈/⌈/pixmat]  ⍝ bug : fully transparent image will display as solid
      png←depth PngFromPixels pixmat
      uri←'data:image/png;base64,',1 Base64 png  ⍝ embedded PNG
    ∇
    ∇ {bytes}←filename Write pixmat;depth;png;tie    ⍝ write image to file as Png
      depth←24 32[1+16777215<⌈/⌈/pixmat]  ⍝ bug : fully transparent image will display as solid
      png←depth PngFromPixels pixmat
      :Trap 22 ⋄ tie←filename ⎕NTIE 0
      :Else ⋄ tie←filename ⎕NCREATE 0
      :EndTrap
      0 ⎕NRESIZE tie
      (⎕UCS png)⎕NAPPEND tie 80
      ⎕NUNTIE tie
    ∇



    ⍝ Internals

    ∇ txt←width Base64 ints;bits;base64;charset;nchars
      bits←,⍉((width×8)⍴2)⊤ints             ⍝ vectors of bits 
      nchars←⌈(≢bits)÷6                     ⍝ number of base64 chars
      base64←2⊥⍉(nchars,6)⍴(6×nchars)↑bits  ⍝ pad bits with zeros to get a multiple of 6 bits
      charset←'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
      txt←charset[1+base64]
      txt,←(3|-width×≢ints)⍴'='             ⍝ pad missing bytes with '='
    ∇
    ∇ bytes←depth PngFromPixels pixmat;shape;height;width;depth;signature;chandepth;ihdr;idat;iend;CRCTABLE;pixels;rgb;scansize;scanlines;alpha
      ⍝ PNG uses more significant byte first
      (height width)←shape←⍴pixmat
      alpha←depth=32
      chandepth←8                           ⍝ depth of each channel in bits
      pixels←,⊖pixmat                       ⍝ first row is top row
      rgb←⍉(+alpha)⊖((3+alpha)⍴256)⊤pixels  ⍝ [pixel;r g b {a}]
      scansize←width×⌈depth÷8               ⍝ number of bytes per scanline (no padding required if depth is a multiple of 8)
      scanlines←height scansize⍴rgb         ⍝ [scanline;bytes]
      signature←137 80 78 71 13 10 26 10
      ihdr←73 72 68 82
      ihdr,←,⍉256 256 256 256⊤width height
      ihdr,←chandepth                       ⍝ bits per sample (i.e. per pixel AND per channel)
      ihdr,←(1+depth=32)⊃2 6                ⍝ colour type (0=greyscale ⋄ 2=true colour ⋄ 3=indexed colour ⋄ 4=greyscale with alpha ⋄ 6=true colour with alpha)
      ihdr,←0                               ⍝ compression must be 0 (zlib/DEFLATE/LZ77)
      ihdr,←0                               ⍝ filter method must be 0 (adaptive filtering with five basic filter types)
      ihdr,←0                               ⍝ no interlace
      idat←73 68 65 84
      idat,←ZLib,0,scanlines                ⍝ filter type 0 : no filtering (appended before each scanline)
      iend←73 69 78 68
      bytes←⊃,/signature(PngChunk ihdr)(PngChunk idat)(PngChunk iend)
    ∇
    ∇ bytes←ZLib bytes;level
    ⍝ RFC 1950 - ZLib has more significant byte first
      level←6   ⍝  ⍝ compression level 0-9
      bytes-←256×bytes>127
      bytes←256|2⊃2 level(219⌶)bytes
    ∇
    ∇ bytes←PngChunk bytes;length
      length←256 256 256 256⊤¯4+≢bytes  ⍝ chunk type already integrated as first four bytes above    ⍝ length ok up to 2GB : we're fine
      bytes←length,bytes,(256 256 256 256⊤Crc32_8 bytes)
    ∇
    ∇ chksum←Crc32_8 bytes;c;i;bits;n;b;inx;one;two;inxs
    ⍝ CRC checksum - slicing by 8 http://create.stephan-brumme.com/crc32/#slicing-by-8-overview
      c←32⍴1 ⍝ 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 ⍝ 2147483647  ⍝ 0xffffffff
      bits←⍉2 2 2 2 2 2 2 2⊤bytes  
      (n b)←0 8⊤≢bytes      ⍝ number of blocks ⋄ number of leftover bytes
      :For i :In ⍳n         ⍝ blocks of 8 bytes
          one←bits[(8×i)-7 6 5 4;]≠(⊖4 8⍴c)
          two←bits[(8×i)-3 2 1 0;]
          inxs←⌽1+2⊥⍉one⍪two
          inxs+←0 256 512 768 1024 1280 1536 1792  ⍝ +\0,7⍴256
          c←≠⌿∆crctable8[inxs;]
      :EndFor
      :For i :In (8×n)+⍳b   ⍝ remaining bytes
          inx←1+2⊥(¯8↑c)≠bits[i;]
          c←∆crctable[inx;]≠(¯32↑¯8↓c)
      :EndFor
      chksum←2⊥+~c          ⍝ return 1's complement
    ∇
    ∇ (crctable crctable8)←CrcTables;c;magic;i;mask;c0;cc
    ⍝ generate CRC table for Crc32_8
      c←(32⍴2)⊤¯1+⍳256    ⍝ [32;256]
      magic←1 1 1 0 1 1 0 1 1 0 1 1 1 0 0 0 1 0 0 0 0 0 1 1 0 0 1 0 0 0 0 0 ⍝ magic←3988292384  ⍝ 0xedb88320L
      :For i :In ⍳8
          mask←c[32;]                   ⍝ c & 1
          c←¯32↑[1]¯1↓[1]c              ⍝ c >> 1
          (mask/c)←magic≠[1](mask/c)    ⍝ magic ^ c
      :EndFor
      crctable←⍉c                       ⍝ [256;32] 
      cc←,⊂c0←c
      :For i :In ⍳7
          cc,←⊂c←(¯32↑[1]¯8↓[1]c)≠(c0[;1+2⊥¯8↑[1]c])
      :EndFor
      crctable8←↑⍪/⍉¨cc     ⍝ [8×256;32] for Crc32_8
    ∇
    (∆crctable ∆crctable8)←CrcTables

:EndNamespace
