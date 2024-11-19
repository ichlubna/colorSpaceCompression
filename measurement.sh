#!/bin/bash
set -x
set -e
FFMPEG=/media/ssd1/Chlubnic/ffmpeg-master-latest-linux64-gpl/bin/ffmpeg
# https://vcgit.hhi.fraunhofer.de/jvet/VVCSoftware_VTM
VVC=/media/ssd1/Chlubnic/VVCSoftware_VTM-master/
# https://github.com/divideon/xvc/tree/master
XVC=/media/ssd1/Chlubnic/xvc-master/build/app/
BLENDER=/media/ssd1/Chlubnic/blender-4.2.0-linux-x64/blender

TEMP=$(mktemp -d)

RESULTS=./results.txt
RESULTS_INVERSE=./resultsInverse.txt
FIRST=$(ls -AU renders | head -1)
SECOND=$(ls -AU renders/$FIRST | head -1)
FRAMES_COUNT=$(ls -1q renders/$FIRST/$SECOND/*  | wc -l)

HEADER="project, profile, bit, codec, crf, psnr, ssim, vmaf, size"
echo $HEADER > $RESULTS
echo $HEADER > $RESULTS_INVERSE

compareAndStore ()
{
    INPUT=$1
    REFERENCE=$2
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE -filter_complex "psnr" -f null /dev/null 2>&1)
    PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE -filter_complex "ssim" -f null /dev/null 2>&1)
    SSIM=$(echo "$RESULT" | grep -oP '(?<=All:).*?(?= )')
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE -lavfi libvmaf -f null /dev/null 2>&1)
    VMAF=$(echo "$RESULT" | grep -oP '(?<=VMAF score: ).*')
    echo $3, $4, $5, $6, $7, $PSNR, $SSIM, $VMAF, $8 >> $9 
}

translateProfile ()
{
    if [[ "$1" == "CanonLog2" ]]; then
        echo "CanonLog2 CinemaGamut D55"
    elif [[ "$1" == "CanonLog3" ]]; then
        echo "CanonLog3 CinemaGamut D55"
    elif [[ "$1" == "S-Log2 ITU-709" ]]; then
        echo "S-Log2 ITU 709 Matrix"
    elif [[ "$1" == "BMDFilm Gen5" ]]; then
        echo "BMDFilm WideGamut Gen5 Log"
    elif [[ "$1" == "DaVinci Intermidiate" ]]; then
        echo "DaVinci Intermidiate WideGamut Log"
    elif [[ "$1" == "Filmlight T-Log - E-Gamut" ]]; then
        echo "T-Log - E-Gamut"
    elif [[ "$1" == "None" ]]; then
        echo "Non-Color"
    elif [[ "$1" == "Standard" ]]; then
        echo "sRGB"
    elif [[ "$1" == "AgX" ]]; then
        echo "AgX Base sRGB"
    elif [[ "$1" == "AgX Kraken" ]]; then
        echo "AgX Base Kraken sRGB"
    elif [[ "$1" == "ACES" ]]; then
        echo "ACES sRGB"
    elif [[ "$1" == "TCAMv2" ]]; then
        echo "TCAMv2 sRGB"
    elif [[ "$1" == "ARRI K1S1" ]]; then
        echo "ARRI K1S1 sRGB"
    elif [[ "$1" == "RED IPP2" ]]; then
        echo "RED IPP2 sRGB"
    elif [[ "$1" == "OpenDRT" ]]; then
        echo "OpenDRT sRGB"
    elif [[ "$1" == "JzDT" ]]; then
        echo "JzDT sRGB"
    elif [[ "$1" == "Khronos Neutral" ]]; then
        echo "Khronos Neutral sRGB"
    else
        echo $1
    fi
}

# $COMPRESSED_FILE $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4
compareAll ()
{
    compareAndStore $1 $2 $3 $4 $5 $6 $7 $8 $9 
    INVERTED_DIR=${10}/inverted_$7/
    mkdir -p $INVERTED_DIR
    PROFILE_NAME_L=$(echo "$4" | tr '_' ' ')
    PROFILE_NAME_L=$(translateProfile $PROFILE_NAME_L)
    INPUT_FILE=$1
    INPUT_FILE="${INPUT_FILE/"%04d"/"0001"}"
    $BLENDER -b --python convert.py -x 1 -- "$PROFILE_NAME_L" "$INPUT_FILE" "$INVERTED_DIR" $FRAMES_COUNT
    compareAndStore $INVERTED_DIR/%04d.png ${11} $3 $4 $5 $6 $7 $8 $RESULTS_INVERSE
}

losslessCompress ()
{
    $FFMPEG -y -i $1 -c:v libx265 -crf 0 -x265-params lossless=1 -pix_fmt yuv444p"$3"le $2
}

COMPRESSED=./compressed
mkdir -p $COMPRESSED
PROJECTS=($(ls -d renders/*))
for PROJECT in $PROJECTS; do
    PROFILES=$(ls -d $PROJECT/*)
    PROJECT_NAME=$(basename $PROJECT)
    COMPRESSED_PROJECT=$COMPRESSED/$PROJECT_NAME
    mkdir -p $COMPRESSED_PROJECT
    REFERENCE_NONE=$COMPRESSED_PROJECT/refNone
    mkdir -p $REFERENCE_NONE
    losslessCompress $PROJECT/None/%04d.png $REFERENCE_NONE/10.mp4 10
    REFERENCE_NONE_12=$COMPRESSED_PROJECT/None_10_REF.mp4
    losslessCompress $PROJECT/None/%04d.png $REFERENCE_NONE/12.mp4 12
    for PROFILE in $PROFILES; do
        PROFILE_NAME=$(basename $PROFILE)
        for BIT in "10" "12"; do
            BIT_DIR=$COMPRESSED_PROJECT/$BIT
            mkdir -p $BIT_DIR
            REF_FILE=$BIT_DIR/$PROFILE_NAME"_REF.mp4"
            losslessCompress $PROFILE/%04d.png $REF_FILE $BIT

            CODEC=libx265
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 9 17 25 33 41 49; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE_NAME"_"$CRF".mp4"
                $FFMPEG -y -i $PROFILE/%04d.png -c:v $CODEC -crf $CRF -pix_fmt yuv444p"$BIT"le $COMPRESSED_FILE
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll $COMPRESSED_FILE $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done

            CODEC=libaom-av1
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 11 21 31 41 51 61; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE_NAME"_"$CRF".mp4"
                $FFMPEG -y -i $PROFILE/%04d.png -c:v $CODEC -cpu-used 8 -row-mt 1 -tiles 2x2 -crf $CRF -pix_fmt yuv444p"$BIT"le $COMPRESSED_FILE
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll $COMPRESSED_FILE $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done

            CODEC=libaom-avif
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 11 21 31 41 51 61; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE_NAME"_"$CRF".mp4"
                $FFMPEG -y -i $PROFILE/%04d.png -c:v libaom-av1 -still-picture 1 -crf $CRF -pix_fmt gbrp"$BIT"le $COMPRESSED_FILE
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll $COMPRESSED_FILE $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4   
            done
 
            CODEC=vvc
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 10 19 28 37 46 55 63; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE_NAME"_"$CRF".bin"
                $FFMPEG -y -i $PROFILE/%04d.png -strict -1 -pix_fmt yuv444p"$BIT"le $TEMP/input.y4m
                $VVC/bin/EncoderAppStatic -fr 25 --InputChromaFormat=444 -i $TEMP/input.y4m -c $VVC/cfg/encoder_lowdelay_P_vtm.cfg -c $VVC/cfg/444/yuv444.cfg --InternalBitDepth=12 -q $CRF -f $FRAMES_COUNT -b $COMPRESSED_FILE
                $VVC/bin/DecoderAppStatic -b $COMPRESSED_FILE -o $TEMP/output.y4m
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                losslessCompress $TEMP/output.y4m $TEMP/output.mp4 $BIT
                compareAll $TEMP/output.mp4 $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done
            
            CODEC=xvc
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 10 19 28 37 46 55 63; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE_NAME"_"$CRF".bin"
                $FFMPEG -y -i $PROFILE/%04d.png -strict -1 -pix_fmt yuv444p"$BIT"le $TEMP/input.y4m
                $XVC/xvcenc -internal-bitdepth 12 -input-file $TEMP/input.y4m -qp $CRF -output-file $COMPRESSED_FILE 
                $XVC/xvcdec -bitstream-file $COMPRESSED_FILE -output-file $TEMP/output.y4m 
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                losslessCompress $TEMP/output.y4m $TEMP/output.mp4 $BIT
                compareAll $TEMP/output.mp4 $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done
 
        done

        BIT_DIR=$COMPRESSED_PROJECT/16
        mkdir -p $BIT_DIR

        CODEC=libjxl
        CODEC_DIR=$BIT_DIR/$CODEC
        mkdir -p $CODEC_DIR
        for CRF in 1 14 27 40 53 66 79 92; do
            COMPRESSED_DIR=$CODEC_DIR/$PROFILE_NAME"_"$CRF
            mkdir -p $COMPRESSED_DIR
            $FFMPEG -y -i $PROFILE/%04d.png -c:v $CODEC -q:v $CRF -pix_fmt rgb48le $COMPRESSED_DIR/%04d.jxl
            SIZE=$(du -bs $COMPRESSED_DIR | cut -f1)
            $FFMPEG -y -i $COMPRESSED_DIR/%04d.jxl -pix_fmt rgb48be $TEMP/%04d.png
            compareAll $TEMP/%04d.png $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
        done

        CODEC=libwebp
        CODEC_DIR=$BIT_DIR/$CODEC
        mkdir -p $CODEC_DIR
        CRF=100
        COMPRESSED_DIR=$CODEC_DIR/$PROFILE_NAME"_"$CRF
        mkdir -p $COMPRESSED_DIR
        $FFMPEG -y -i $PROFILE/%04d.png -c:v $CODEC -lossless 1 -q:v $CRF -pix_fmt bgra $COMPRESSED_DIR/%04d.webp
        SIZE=$(du -bs $COMPRESSED_DIR | cut -f1)
        $FFMPEG -y -i $COMPRESSED_DIR/%04d.webp -pix_fmt rgb48be $TEMP/%04d.png
        compareAll $TEMP/%04d.png $REF_FILE $PROJECT_NAME $PROFILE_NAME $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    

    done
done
rm -rf $TEMP
