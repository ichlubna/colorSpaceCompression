PROJECTS=$(ls projects/*.blend)
DISPLAYS=("Camera Log" "Log" "sRGB")
VIEWS_CAMERA_LOG=("CanonLog2" "CanonLog3" "V-Log V-Gamut" "S-Log2 - ITU-709" "S-Log3 - S-Gamut3" "F-Log F-Gamut" "F-Log2 F-Gamut" "D-Log D-Gamut" "ProTune Log" "N-Log" "AppleLog" "BMDFilm Gen5") 
VIEWS_LOG=("AgX Log" "DaVinci Intermidiate" "Filmlight T-Log - E-Gamut")
VIEWS_SRGB=("None" "Standard" "AgX" "AgX Kraken" "ACES" "TCAMv2" "ARRI K1S1" "RED IPP2" "OpenDRT" "JzDT" "Khronos Neutral")
VIEWS=( "${VIEWS_CAMERA_LOG[@]}" "${VIEWS_LOG[@]}" "${VIEWS_SRGB[@]}" )
BLENDER=blender

echo ${VIEWS[@]}

for PROJECT in "${PROJECTS[@]}"; do
    I=0
	for VIEW in "${VIEWS[@]}"; do
        if [ $I -lt ${#VIEWS_CAMERA_LOG[@]} ]; then
            DISPLAY=${DISPLAYS[0]}
        elif [ $I -lt $((${#VIEWS_CAMERA_LOG[@]} + ${#VIEWS_LOG[@]})) ]; then
            DISPLAY=${DISPLAYS[1]}
        else
            DISPLAY=${DISPLAYS[2]}
        fi
        PROJECT_NAME=$(basename -- "$PROJECT")
        PROJECT_NAME="${PROJECT_NAME%.*}"
        $($BLENDER -b $PROJECT --python render.py -x 1 -o ./renders/$PROJECT_NAME/$VIEW/ -f 1 -- "$DISPLAY" "$VIEW")
        I=$((I+1))
    done
done

