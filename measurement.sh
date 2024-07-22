#!/bin/bash
FFMPEG=ffmpeg
# https://vcgit.hhi.fraunhofer.de/jvet/VVCSoftware_VTM
VVC=/home/ichlubna/Workspace/VVCSoftware_VTM/
# https://github.com/divideon/xvc/tree/master
XVC=/home/ichlubna/Workspace/xvc/build/app/
BLENDER=blender

TEMP=$(mktemp -d)

$RESULTS=./results.txt
$RESULTS_INVERSE=./resultsInverse.txt
echo "project, profile, bit, codec, crf, psnr, ssim, vmaf, size" > $RESULTS
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
    echo $3, $4, $5, $6, $7, $PSNR, $SSIM, $VMAF, $8 > $9 
}


# $COMPRESSED_FILE $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4
compareAll ()
{
    compareAndStore $1 $2 $3 $4 $5 $6 $7 $8 $9 
    INVERTED_DIR=${10}/inverted_$7
    mkdir -p $INVERTED_DIR
    PROFILE_NAME=$(echo "$VIEW" | tr '_' ' ')
    $BLENDER -b --python convert.py -x 1 -- "$PROFILE_NAME" "$COMPRESSED_FILE" "$INVERTED_DIR"
    compareAndStore $INVERTED_DIR/%04d.png ${11} $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS_INVERSE
}

losslessCompress ()
{
    $FFMPEG -i $1 -c:v libx265 -crf 0 -x265-params lossless=1 -pix_fmt yuv444p"$3"le $2
}

COMPRESSED=./compressed
mkdir -p $COMPRESSED
PROJECTS=($(ls -d renders/*))
for PROJECT in $PROJECTS; do
    PROFILES=($(ls -d $PROJECT/*))
    COMPRESSED_PROJECT=$COMPRESSED/$PROJECT
    mkdir -p $COMPRESSED_PROJECT
    REFERENCE_NONE=$COMPRESSED_PROJECT/refNone
    mkdir -p $REFERENCE_NONE
    losslessCompress $PROJECT/None/%04d.png $REFERENCE_NONE/10.mp4 10
    REFERENCE_NONE_12=$COMPRESSED_PROJECT/None_10_REF.mp4
    losslessCompress $PROJECT/None/%04d.png $REFERENCE_NONE/12.mp4 12
    for PROFILE in $PROFILES; do
        for BIT in "10" "12"; do
            BIT_DIR=$COMPRESSED_PROJECT/$BIT
            mkdir -p $BIT_DIR
            REF_FILE=$BIT_DIR/$PROFILE"_REF.mp4"
            losslessCompress $PROFILE/%04d.png $REF_FILE $BIT

            CODEC=libx265
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 9 17 25 33 41 49; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE"_"$CRF".mp4"
                $FFMPEG -i $PROFILE/%04d.png -c:v $CODEC -crf $CRF -pix_fmt yuv444p"$BIT"le $COMPRESSED_FILE
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll  $COMPRESSED_FILE $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done

            CODEC=libaom-av1
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 11 21 31 41 51 61; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE"_"$CRF".mp4"
                $FFMPEG -i $PROFILE/%04d.png -c:v $CODEC -cpu-used 8 -row-mt 1 -tiles 2x2 -crf $CRF -pix_fmt yuv444p"$BIT"le $COMPRESSED_FILE
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll  $COMPRESSED_FILE $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done

            CODEC=libaom-avif
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 11 21 31 41 51 61; do
                COMPRESSED_DIR=$CODEC_DIR/$PROFILE"_"$CRF
                mkdir -p $COMPRESSED_DIR
                $FFMPEG -i $PROFILE/%04d.png -c:v libaom-av1 -still-picture 1 -crf $CRF -pix_fmt gbrp"$BIT"le $COMPRESSED_DIR/%04d.avif
                SIZE=$(du -bs $COMPRESSED_DIR | cut -d "     " -f1)
                compareAll  $COMPRESSED_DIR/%04d.avif $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done
 
            CODEC=vvc
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 10 19 28 37 46 55 63; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE"_"$CRF".bin"
                $FFMPEG -y -i $PROFILE/%04d.png -strict -1 -pix_fmt yuv444p"$BIT"le $TEMP/input.y4m
                $VVC/bin/EncoderAppStatic -fr 25 --InputChromaFormat=444 -i $TEMP/input.y4m -c $VVC/cfg/encoder_lowdelay_P_vtm.cfg -c $VVC/cfg/444/yuv444.cfg --InternalBitDepth=12 -q $CRF -f 100 -b $COMPRESSED_FILE
                $VVC/bin/DecoderAppStatic -b $COMPRESSED_FILE -o $TEMP/output.y4m
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll  $TEMP/output.y4m $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done
            
            CODEC=xvc
            CODEC_DIR=$BIT_DIR/$CODEC
            mkdir -p $CODEC_DIR
            for CRF in 1 10 19 28 37 46 55 63; do
                COMPRESSED_FILE=$CODEC_DIR/$PROFILE"_"$CRF".bin"
                $FFMPEG -y -i $PROFILE/%04d.png -strict -1 -pix_fmt yuv444p"$BIT"le $TEMP/input.y4m
                $XVC/xvcenc -internal-bitdepth 12 -input-file $TEMP/input.y4m -qp $CRF -output-file $COMPRESSED_FILE 
                $XVC/xvcdec -bitstream-file $COMPRESSED_FILE -output-file $TEMP/output.y4m 
                SIZE=$(stat --printf="%s" $COMPRESSED_FILE)
                compareAll  $TEMP/output.y4m $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
            done
       
        done

        CODEC=libjxl
        CODEC_DIR=$BIT_DIR/$CODEC
        mkdir -p $CODEC_DIR
        for CRF in 1 14 27 40 53 66 79 92; do
            COMPRESSED_DIR=$CODEC_DIR/$PROFILE"_"$CRF
            mkdir -p $COMPRESSED_DIR
            $FFMPEG -i $PROFILE/%04d.png -c:v $CODEC -q:v $CRF -pix_fmt rgb48le $COMPRESSED_DIR/%04d.jxl
            SIZE=$(du -bs $COMPRESSED_DIR | cut -d "     " -f1)
            compareAll  $COMPRESSED_DIR/%04d.jxl $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    
        done

        CODEC=libwebp
        CODEC_DIR=$BIT_DIR/$CODEC
        mkdir -p $CODEC_DIR
        CRF=100
        COMPRESSED_DIR=$CODEC_DIR/$PROFILE"_"$CRF
        mkdir -p $COMPRESSED_DIR
        $FFMPEG -i $PROFILE/%04d.png -c:v $CODEC -lossless 1 -q:v $CRF -pix_fmt bgra $COMPRESSED_DIR/%04d.webp
        SIZE=$(du -bs $COMPRESSED_DIR | cut -d "     " -f1)
        compareAll  $COMPRESSED_DIR/%04d.webp $REF_FILE $PROJECT $PROFILE $BIT $CODEC $CRF $SIZE $RESULTS $CODEC_DIR $REFERENCE_NONE/$BIT.mp4    

    done
done
rm -rf $TEMP
