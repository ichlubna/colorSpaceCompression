#!/bin/bash
set -x
#set -e

FFMPEG=ffmpeg
# https://vcgit.hhi.fraunhofer.de/jvet/VVCSoftware_VTM
VVENC=/run/media/ichlubna/Amaterasu/uvg/vvenc/bin/release-static/vvencapp
VVDEC=/run/media/ichlubna/Amaterasu/uvg/vvdec/bin/release-static/vvdecapp
BLENDER=/run/media/ichlubna/Amaterasu/uvg/blender-4.5.4-linux-x64/blender
TEMP=$(mktemp -d)

# Using dataset https://ultravideo.fi/dataset.html, all yuv files moved to one dir
INPUT_DIR=$1
RESULTS_DIR=$2
FRAMES_COUNT=25
HEADER="profile, crf, psnr, ssim, vmaf, size"
PROFILES=('ACEScc' 'ARRI K1S1 sRGB') # 'AgX Base Kraken sRGB' 'AgX Base sRGB' 'AgX Log' 'Apple Log' 'BMDFilm WideGamut Gen5 Log' 'CanonLog2 CinemaGamut D55' 'CanonLog3 CinemaGamut D55' 'D-Log D-Gamut' 'DaVinci Intermidiate WideGamut Log' 'F-Log F-Gamut' 'F-Log2 F-Gamut' 'JzDT sRGB' 'Khronos Neutral sRGB' 'N-Log' 'Non-Color' 'OpenDRT Default sRGB' 'ProTune Log' 'RED IPP2 sRGB' 'S-Log2 S-Gamut' 'S-Log3 S-Gamut3' 'TCAMv2 sRGB' 'V-Log V-Gamut' 'sRGB' 'T-Log - E-Gamut')

for INPUT_FILE in $INPUT_DIR/*; do
    if [[ "$INPUT_FILE" == *.yuv ]]; then
        FILE_NAME=$(basename $INPUT_FILE .yuv)
        REFERENCE_DIR=$TEMP/$FILE_NAME"_reference"
        mkdir -p $REFERENCE_DIR
        $FFMPEG -f rawvideo -pix_fmt yuv420p10le -s:v 3840x2160 -r 120 -i $INPUT_FILE -vframes $FRAMES_COUNT -vf scale=-1:1080 $REFERENCE_DIR/%04d.exr
        INPUT_PROFILE="Rec.2020"
    elif [[ "$INPUT_FILE" == *.rar ]]; then
        FILE_NAME=$(basename "$INPUT_FILE" .rar)
        REFERENCE_DIR=$TEMP/"$FILE_NAME""_reference"
        mkdir -p "$REFERENCE_DIR"
        mkdir -p ./extract
        unrar x "$INPUT_FILE" ./extract/
        FIRST=$(ls -d ./extract/*/ | head -n 1)
        i=1
        find "$FIRST" -maxdepth 1 -type f | sort | head -n 25 | while read -r file; do
            printf -v newname "%04d.exr" "$i"
            cp "$file" "$REFERENCE_DIR/$newname"
            ((i++))
        done
        rm -rf ./extract
        INPUT_PROFILE="Rec.2100-PQ"
    else
        continue
    fi

    echo $INPUT_FILE
    RESULTS="$RESULTS_DIR/$FILE_NAME.csv"
    echo $HEADER > "$RESULTS"
    
    #$FFMPEG -f rawvideo -pix_fmt yuv420p10le -s:v 3840x2160 -r 120 -i $INPUT_FILE -vframes $FRAMES_COUNT -vf scale=-1:1080 -pix_fmt yuv444p16le -strict -1 $REFERENCE

    for PROFILE in "${PROFILES[@]}"; do
        PROFILE_DIR="$TEMP/$PROFILE"
        CONVERTED="$PROFILE_DIR/converted"
        mkdir -p "$PROFILE_DIR"
        mkdir -p "$CONVERTED"
        $BLENDER -b --python uvgConvert.py -x 1 -- "$PROFILE" "$REFERENCE_DIR"/"0001.exr" "$CONVERTED/" "$INPUT_PROFILE" 
        CONVERTED_FILE=$PROFILE_DIR/converted.y4m
        $FFMPEG -i "$CONVERTED/%04d.png" -pix_fmt yuv420p10le -strict -1 "$CONVERTED_FILE"

        for CRF in 1 10 19 28 37 46 55 63; do
            COMPRESSED_FILE="$PROFILE_DIR"/$CRF".266"
            DECOMPRESSED_FILE="$PROFILE_DIR"/$CRF"_dec.y4m"

            $VVENC -i "$CONVERTED_FILE" -c yuv420_10 --preset slow -q $CRF -o "$COMPRESSED_FILE"
            SIZE=$(stat --printf="%s" "$COMPRESSED_FILE")
            $VVDEC -b "$COMPRESSED_FILE" -o "$DECOMPRESSED_FILE"
            
            RESULT=$($FFMPEG -i "$DECOMPRESSED_FILE" -i "$CONVERTED_FILE" -filter_complex "psnr" -f null /dev/null 2>&1)
            PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
            RESULT=$($FFMPEG -i "$DECOMPRESSED_FILE" -i "$CONVERTED_FILE" -filter_complex "ssim" -f null /dev/null 2>&1)
            SSIM=$(echo "$RESULT" | grep -oP '(?<=All:).*?(?= )')
            RESULT=$($FFMPEG -i "$DECOMPRESSED_FILE" -i "$CONVERTED_FILE" -lavfi libvmaf -f null /dev/null 2>&1)
            VMAF=$(echo "$RESULT" | grep -oP '(?<=VMAF score: ).*')
            echo "$PROFILE", $CRF, $PSNR, $SSIM, $VMAF, $SIZE >> "$RESULTS"
        done
        rm -rf "$PROFILE_DIR"
    done
    rm -rf $REFERENCE_DIR
done
rm -rf $TEMP
