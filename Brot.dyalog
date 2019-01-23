:Namespace Brot

    ⎕IO ⎕ML←1 1

    ⍝ To do :
    ⍝ - Buddhabrot : the edge pixels are halved because of the way we tile the samples
    ⍝ - Buddhabrot : rather than specifying density, should give 2 sets of (x y∘.∘steps min max) : one for starting set, one for output pixels

    ∇ mask←IsMandelbrot values;p;x;x2;y;y2
    ⍝ spot points that are guaranteed not to escape (within Mandelbrot set)
      (x y)←9 11○¨⊂values
      p←0.5*⍨⊃+/(x2 y2)←×⍨(x-0.25)y ⍝ p = sqrt(((x-1÷4)*2)+(y*2))
      mask←x<p+0.25+¯2××⍨p          ⍝ x < p + (1÷4) - (2×p*2)
      mask∨←0.0625>y2+(×⍨x+1)       ⍝ ((x+1)*2) + (y*2) < (1÷16)
    ∇

    ∇ weight←Mandelbrot(xsteps ysteps xmin ymin xmax ymax iterations);count;cur;esc;hist;i;inx;nesc;set;sets;x;y
    ⍝ count number of iterations before escape (maximum value is iterations for points that don't escape)
      :Access Public Shared
      x←xmin+(xmax-xmin)×(¯1+⍳xsteps)÷(¯1+xsteps)
      y←ymin+(ymax-ymin)×(¯1+⍳ysteps)÷(¯1+ysteps)
      cur←set←,(0J1×y)∘.+x
      inx←⍳≢count←(≢set)⍴iterations     ⍝ points that don't escape get maximum value
      (cur inx)←(~IsMandelbrot set)∘/¨(cur inx)  ⍝ trim points that are known not to escape
      :For i :In ⍳iterations
          esc←4<cur×+cur                ⍝ these will never come back
          count[esc/inx]←i              ⍝ store iteration number at which they escaped
          (cur inx)←(~esc)∘/¨(cur inx)  ⍝ stop computation for escaped points
          :If 0∊⍴inx ⋄ :Leave ⋄ :EndIf  ⍝ all have escaped ⋄ done
          cur←set[inx]+×⍨cur            ⍝ Mandelbrot step : z←c+z*2
      :EndFor
      count←(ysteps xsteps)⍴count
      ⍝ linear normalisation from [1;iterations] to [0;1]
      weight←(¯1+count)÷(¯1+iterations)
    ∇

    ∇ weight←Buddhabrot(xsteps ysteps xmin ymin xmax ymax iterations density);chunk;count;cur;cutoff;esc;hinx;hist;i;inx;inxs;mask;max;min;nesc;ratio;rx;ry;set;sets;x;xi;y;yi
    ⍝ track visited points for those that do escape to infinity over given number of iterations
    ⍝ density gives the number of points per pixel
      count←(ysteps×xsteps)⍴0
      chunk←(⎕WA÷20)÷iterations             ⍝ worst possible number of (16-byte complex + 4-byte index)
      chunk÷←2+iterations<10                ⍝ we have two copies of the whole data set at ravel time, and copies in the iteration loop count too when the number of iterations is low
      chunk←chunk*0.5                       ⍝ chunk size in x/y
      chunk←1⌈⌊chunk                        ⍝ round down to be safe
      :If chunk≤3                           ⍝ less than 3×3←→9 series at a time is kind of hopeless because the APL overhead will become stupid
          ⎕←'Buddhabrot warning: not enough MAXWS or too many iterations - code will become stupidly slow as iterations raise, and will eventually WS FULL'
      :EndIf
      x←xmin+(xmax-xmin)×{(¯1+⍳⍵)÷(¯1+⍵)}⌊0.5+xsteps×density*0.5
      y←ymin+(ymax-ymin)×{(¯1+⍳⍵)÷(¯1+⍵)}⌊0.5+ysteps×density*0.5
      (x y)←chunk{((≢⍵)⍴⍺↑1)⊂⍵}¨(x y)
      :For xi yi :In ⍳≢¨x y
          set←,(0J1×yi⊃y)∘.+(xi⊃x)
          set←(~IsMandelbrot set)/set       ⍝ ignore areas that are known to be part of the Mandelbrot set
          inx←⍳≢cur←set                     ⍝ indices of points still on the run
          sets←inxs←⍬                       ⍝ do not include initial points
          :For i :In ⍳iterations
              esc←4<cur×+cur
              (cur inx)←(~esc)∘/¨(cur inx)
              :If 0∊⍴inx ⋄ :Leave ⋄ :EndIf
              cur←set[inx]+×⍨cur
              sets,←⊂cur ⋄ inxs,←⊂inx       ⍝ store all intermediate steps
          :EndFor
          (sets inxs)←∊¨(sets inxs)         ⍝ ravel it all
          sets←(~inxs∊inx)/sets ⋄ ⎕EX'inxs' ⍝ trim points that haven't escaped
          (rx ry)←9 11○¨⊂sets
          mask←(xmin≤rx)∧(rx≤xmax)∧(ymin≤ry)∧(ry≤ymax)
          (rx ry)←mask∘/¨(rx ry)
          xi←⌊0.5+(xsteps-1)×(rx-xmin)÷(xmax-xmin)
          yi←⌊0.5+(ysteps-1)×(ry-ymin)÷(ymax-ymin)
          count[1+ysteps xsteps⊥yi,[0.5]xi]+←1
      :EndFor
      ⍝ cut off the edges from the histogram (very few values have uncommonly extreme values)
      cutoff←0.001÷density
      hist←(1+⌈/count)⍴0 ⋄ hist[1+count]+←1
      hist←(0,+\hist)÷(≢count)  ⍝ from 0 to 1
      hinx←⍳⍨hist ⋄ (hist hinx)←(hinx=⍳≢hist)∘/¨(hist hinx)
      (min max)←hinx[hist⍸0 1+1 ¯1×cutoff]
      weight←0⌈1⌊(count-min)÷(max-min)
      weight←(ysteps xsteps)⍴weight
      weight←⍉⌽weight           ⍝ Buddha sits up
    ∇

    ∇ colors←palette ColorMap value;inx;weight
    ⍝ encode value∊[0;1] into the given palette by linear interpolation
    ⍝ result has shape ((⍴value),(1↓⍴palette))
      (inx weight)←⊂[1↓⍳3]0 1⊤value×¯1+≢palette
      colors←+⌿((1-weight),[0.5](weight))×[⍳3](⊂1 2∘.+inx)⌷palette⍪0
    ∇

    ∇ pixmat←{cycle}MandelbrotImage(width height xmin ymin xmax ymax iterations);bw;cycles;palette;pixmat
    ⍝ cycle is a boolean enabling color cycling that reveals psychedelic details of the set
    ⍝ disabling it uses a single color cycle over the escape time, allowing accurate reading of the escape time
    ⍝ in all cases, white points are those that diverge at 0 iteration,
    ⍝ and black points at those that do not diverge after the maximum number of iterations.
    ⍝ This means that non-black points cannot be in the Mandelbrot set,
    ⍝ while black points are good candidates (given the number of iterations) but are not guaranteed to be in it.
      :If 0=⎕NC'cycle' ⋄ cycle←0 ⋄ :EndIf
      palette←(0 255 0)(0 255 255)(0 0 255)(255 0 255)(255 0 0)(255 255 0) ⍝ green cyan blue magenta red yellow
      cycles←(cycle≠0)×⌊iterations÷500              ⍝ approx. 500 shades per cycle
      palette←(cycles×≢palette)⍴palette
      palette,⍨←(255 255 255)(255 0 0)(255 255 0)   ⍝ white red yellow , cycle
      palette,←(0 255 0)(0 255 255)(0 0 255)(0 0 0) ⍝ cycle , green cyan blue black
      pixmat←(↑palette)ColorMap Mandelbrot width height xmin ymin xmax ymax iterations
      pixmat←256⊥(1⌽⍳3)⍉⌊0.5+pixmat
    ∇

    ∇ pixmat←BuddhabrotImage(width height xmin ymin xmax ymax iterations density);palette;pixmat
    ⍝ computation will be incomplete if (xmin ymin xmax ymax) does not include the circle of radius 2
      palette←(0 0 0)(255 255 255)  ⍝ 256 shades of grey
      pixmat←(↑palette)ColorMap Buddhabrot width height xmin ymin xmax ymax iterations density
      pixmat←256⊥(1⌽⍳3)⍉⌊0.5+pixmat
    ∇

    ∇ directory AnimatedBuddhabrot(width height density);base;cat;crop;cropname;digits;drop;ffmpeg;filelist;filename;filenames;h;i;iterations;pixmat;time;w;x;xmax;xmin;y;ymax;ymin;win;sep;input
    ⍝ Build a list of Buddhabrot images from 2 to 20000 iterations,
    ⍝ then use FFMPEG to make a video
      win←'Windows'≡7↑⊃'.'⎕WG'APLVersion'
      :If ~(⊃⌽directory)∊'/\' ⋄ directory,←'/' ⋄ :EndIf
      ⍝:If win ⋄ directory←('/'⎕R'\\')directory ⋄ :EndIf  ⍝ ⎕NTIE works with '/' but ⎕CMD doesn't
      :If win ⋄ directory←('\\'⎕R'/')directory ⋄ :EndIf  ⍝ ffmpeg expects '/'
      base←'buddhabrot_',(⍕width),'x',(⍕height),'d',(⍕density)
      (xmin ymin xmax ymax)←2/¯2 2
      drop←⌊width height÷4
      iterations←2 3 4 5 6 7 8 9
      iterations,←10 12 14 16 18
      iterations,←20 25 30 40 50 75
      iterations,←100 150 200 300
      iterations,←500 1000 2000 3000 5000
      iterations,←10000 15000 20000
      digits←1+⌊10⍟⌈/iterations
      filenames←↓⎕D[1+⍉(digits⍴10)⊤iterations]
      filenames←,/(⊂base,'i'),filenames,[1.5](⊂'.png')
      :For i :In ⌽⍳⍴iterations
          filename←directory,i⊃filenames
          :If ~⎕NEXISTS filename
              ⎕←filename,'...' ⋄ time←3⊃⎕AI
              :Trap 1
                  pixmat←BuddhabrotImage width height xmin ymin xmax ymax(i⊃iterations)density
                  filename #.Png.Write pixmat
                  time←(3⊃⎕AI)-time ⋄ ⎕←((⍴filename)⍴' '),'...',(⍕time),'ms'
              :Else
                  ⎕←((⍴filename)⍴' '),'...WS FULL'
              :EndTrap
          :EndIf
      :EndFor
      filelist←(40,⍨(¯1+⍴filenames)⍴1)/filenames  ⍝ repeat last image for some time
      filelist←{'file ''',⍵,''''}¨filelist        ⍝ file list as expected by ffmpeg
      (w h x y)←⌊0.5+(4⍴width height)×0.5 0.75 0.25 0
      crop←',crop=',(⍕w),':',(⍕h),':',(⍕x),':',(⍕y)  ⍝ width:height:left:top
      ffmpeg←'ffmpeg',win/'.exe'
      :For crop :In ''crop
          :If ~⎕NEXISTS cropname←directory,base,((~0∊⍴crop)/'_crop'),'.mp4'
              input←directory,base,((~0∊⍴crop)/'_crop'),'.txt'
              (⊂filelist)⎕NPUT input 1
              ⎕←⎕SH ⎕←ffmpeg,' -r 5 -f concat -safe 0 -i "',input,'" -c:v libx264 -vf "fps=25,format=yuv420p',crop,'" -y "',cropname,'"'
          :EndIf
      :EndFor
      ⎕←'Finished'
    ∇

    ⎕←'      ''./mandelbrot.png'' #.Png.Write #.Brot.MandelbrotImage 2000 2000 ¯2 ¯2 2 2 100           ⍝ takes about 2 sec.'
    ⎕←'      ''./mandelbrot_zoom.png'' #.Png.Write 1 #.Brot.MandelbrotImage 2000 2000 ¯1.093 0.235 ¯1.091 0.237 1000 ⍝ takes about 30 sec.'
    ⎕←'      ''./buddhabrot_d1.png'' #.Png.Write #.Brot.BuddhabrotImage 2000 2000 ¯2 ¯2 2 2 20000 1 ⍝ takes about 30 sec.'
    ⎕←'      ''./buddhabrot_d20.png'' #.Png.Write #.Brot.BuddhabrotImage 2000 2000 ¯2 ¯2 2 2 20000 20 ⍝ takes about 10 min.'
    ⎕←'      ''.'' #.Brot.AnimatedBuddhabrot 2000 2000 1   ⍝ 1GB MAXWS required - takes about 3 min.'
    ⎕←'      ''.'' #.Brot.AnimatedBuddhabrot 2000 2000 20  ⍝ 1GB MAXWS required - takes about 30 min.'
:EndNamespace
