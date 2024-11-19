import glob
import sys

header = "project, profile, bit, codec, crf, psnr, ssim, vmaf, size\n"
with open('out.txt', 'w') as f:
    f.write(header)
    for filepath in glob.iglob(sys.argv[1]'/*'):
        sample = open(filepath, "r")
        for line in sample:
            if line.strip() and line != header:
                f.write(line)
