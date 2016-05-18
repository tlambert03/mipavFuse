#!/bin/bash

# recommended to set mipav binary path as environmental variable MIPAV
# or change this to the path of your mipav binary


# check environment
if [ "$(uname)" == "Darwin" ]; then
    # we're on a mac
    NPROC=`sysctl -n hw.ncpu`
    OS='mac'
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # we're on a linux box
    NPROC=`nproc`
    OS='linux'
elif [ "$(expr substr $(uname -s) 1 6)" == "CYGWIN" ]; then
    # we're using Cygwin on windows
    NPROC=`nproc`
    OS='cygwin'
else
    echo 'Uknown operating system, this script may not work correctly'
    echo 'Setting number of processes to 4...'
    NCORES=4
fi


# if you define $MIPAV as an environmental variable, this script will find it here
# otherwise, you should hardcode the path to the MIPAV executable in the last conditional here
if [[ -x "$MIPAV" ]]; then 
    # the golab mipav MIPAV variable exists and is an executable
    :
elif [[ -n "$MIPAV" ]]; then
    # $MIPAV is at least defined
    :
else
    # $MIPAV is not defined... you can place a hardcoded path to the 
    # MIPAV executable here as a fallback
    echo the MIPAV variable is undefined
    MIPAV=/home/tjl10/mipav/mipav
fi

# DEFAULT VALUES
# feel free to edit these as needed
Xres=0.1625 # X pixel size
Yres=0.1625 # Y pixel size
Zres=0.5  # Z step size
BASE=SPIMB
DCON_BOOL=true # whether to perform deconvolution
DCON_SIGA_X=3.5 
DCON_SIGA_Y=3.5
DCON_SIGA_Z=9.6
DCON_SIGB_X=3.5
DCON_SIGB_Y=3.5
DCON_SIGB_Z=9.6
DCON_PLATFORM=1 # 1 is CPU ... 2 is OpenCL on GPU
ROT_RANGE=10
SAVE_MAX=true # whether to save max projections
XMAX=false # save x max projection
YMAX=false # save y max projection
ZMAX=true # save z max projection
FUSION_RANGE='' # range of timepoints to fuse (empty string means all timepoints)
SAVE_PREFUSION=false
TRANS_ROT=5 # 5 is -90 Y ... 4 is +90 Y

function Usage()
{
cat <<-ENDOFMESSAGE
MIPAV GenerateFusion helper script.
Talley Lambert :: May 2016 :: talley.lambert@gmail.com

NOTE: This script requires MIPAV Nightly Build > 03/23/2016 
      in order to fuse a subset of images in the directory
      with the '-r' flag

$0 [OPTIONS] DIRECTORY

Starts MIPAV fusion of DIRECTORY, assuming subfolder structure of:
--DIR
  --SPIMA
  --SPIMB

options:

    FLAGS         {DEFAULT}         EXPLANATION
    -b --base 	  A | {B}           base image (i.e. transform TO this image, SPIMA/SPIMB)
    -z --zstep    {0.5}               Z step size in microns
    -x --xpix     {0.1625}          X pixel size
    -y --ypix     {0.1625}          Y pixel size
    -r --range    {all images}      range of image number to fuse (e.g. 1-5,10,12)
    -n --proc	  {max}             number of concurrent processes.
    -o --rotrange {10}              rotation range when registering
    -t --transrot {-90Y} | {+90Y}   rotate transform image prior to registration 
    -p --savepre  {false} | true    save prefusion images

    -d --decon    {true} | false    perform joint deconvolution after registration
    --dconsigAX   {3.5}             sigma of SPIMA PSF in X (in SPIMA coordinates)
    --dconsigAY   {3.5}             sigma of SPIMA PSF in Y (in SPIMA coordinates)
    --dconsigAZ   {9.6}             sigma of SPIMA PSF in Z (in SPIMA coordinates)
    --dconsigBX   {3.5}             sigma of SPIMB PSF in X (in SPIMB coordinates)
    --dconsigBY   {3.5}             sigma of SPIMB PSF in Y (in SPIMB coordinates)
    --dconsigBZ   {9.6}             sigma of SPIMB PSF in Z (in SPIMB coordinates)

    -m --savemax  {true}  | false   save max projections
    -j --xmax     {false} | true    perform X max intensity projection
    -k --ymax     {false} | true    perform Y max intensity projection
    -l --zmax     {true}  | false   perform Z max intensity projection
  
    -h --help       display this message

ENDOFMESSAGE
    exit 1
}

function Die()
{
    echo "$*"
    exit 1
}

function checkbool(){
    if [ "$1" == "true" ] || [ "$1" == "false" ]; then 
        echo 1; 
    else
        echo 0
    fi
}

function GetOpts() {
    branch=""
    argv=()
    while [ $# -gt 0 ]
    do
        opt=$1
        shift
        case ${opt} in

            -b|--base)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                if [ "$1" == "A" ] || [ "$1" == "SPIMA" ]; then
                    BASE=SPIMA;
                elif [ "$1" == "B" ] || [ "$1" == "SPIMB" ]; then
                    BASE=SPIMB;
                else
                    Die "The ${opt} option must be either A, B, SPIMA, or SPIMB."
                fi
                shift
                ;;
            -z|--zstep)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                Zres="$1"
                shift ;;
            -x|--xpix)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                Xres="$1"
                shift ;;
            -y|--ypix)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                Yres="$1"
                shift ;; 
            -r|--range)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                FUSION_RANGE="$1"
                shift ;;
            -n|--proc)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                NPROC="$1"
                shift ;;
            -o|--rotrange)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                ROT_RANGE="$1"
                shift ;;
            -t|--transrot)
                if [ $# -eq 0 -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ "$1" == "-90Y" ]; then 
                    TRANS_ROT=5;
                elif [ "$1" == "+90Y" ]; then 
                    TRANS_ROT=4;
                else
                    Die "The ${opt} option must be either -90Y or +90Y ";
                fi
                shift ;;
            -p|--savepre)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ `checkbool $1` == 1 ]; then 
                    SAVE_PREFUSION="$1"                
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift ;;
            -m|--savemax)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ `checkbool $1` == 1 ]; then 
                    SAVE_MAX="$1"                
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift ;;
            
            -j|--xmax)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ `checkbool $1` == 1 ]; then 
                    XMAX="$1"
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift ;;
            -k|--ymax)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ `checkbool $1` == 1 ]; then 
                    YMAX="$1"
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift ;;
            -l|--zmax)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                if [ `checkbool $1` == 1 ]; then 
                    ZMAX="$1"
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift ;;

            -d|--decon)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                if [ `checkbool $1` == 1 ]; then 
                    DCON_BOOL="$1"
                else 
                    Die "The ${opt} argument must be true or false.";
                fi
                shift
                ;;

            --dconsigAX)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGA_X="$1"
                shift ;;
            --dconsigAY)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGA_Y="$1"
                shift ;;
            --dconsigAZ)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGA_Z="$1"
                shift ;;
            --dconsigBX)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGB_X="$1"
                shift ;;
            --dconsigBX)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGB_Y="$1"
                shift ;;
            --dconsigBX)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                DCON_SIGB_Z="$1"
                shift ;;

            -h|--help)
                Usage;;
            *)
                if [ "${opt:0:1}" = "-" ]; then
                    Die "${opt}: unknown option."
                fi
                argv+=(${opt});;
        esac
    done 
}

GetOpts $*

#echo "argv ${argv[@]}"
PARENT_DIR=${argv[0]} # only process first argument for now... could expand

[ -d $PARENT_DIR/MTX ] || mkdir $PARENT_DIR/MTX


# this is where we generate the script file that we will call from MIPAV
SS='nibib.spim.PlugInDialogGenerateFusion('
SS="${SS}\"reg_one boolean false\", "
SS="${SS}\"reg_all boolean true\", "
SS="${SS}\"no_reg_2D boolean false\", "
SS="${SS}\"reg_2D_one boolean false\", "
SS="${SS}\"reg_2D_all boolean false\", "
SS="${SS}\"rotate_begin list_float -${ROT_RANGE}.0,-${ROT_RANGE}.0,-${ROT_RANGE}.0\", "
SS="${SS}\"rotate_end list_float ${ROT_RANGE}.0,${ROT_RANGE}.0,${ROT_RANGE}.0\", "
SS="${SS}\"coarse_rate list_float 3.0,3.0,3.0\", "
SS="${SS}\"fine_rate list_float 1.0,1.0,1.0\", "
SS="${SS}\"save_arithmetic boolean false\", "
SS="${SS}\"show_arithmetic boolean false\", "
SS="${SS}\"save_geometric boolean false\", "
SS="${SS}\"show_geometric boolean false\", "
SS="${SS}\"do_interImages boolean false\", "
SS="${SS}\"save_prefusion boolean $SAVE_PREFUSION\", "
SS="${SS}\"do_show_pre_fusion boolean false\", "
SS="${SS}\"do_threshold boolean false\", "
SS="${SS}\"save_max_proj boolean $SAVE_MAX\", "
SS="${SS}\"show_max_proj boolean false\", "
SS="${SS}\"x_max_box_selected boolean $XMAX\", "
SS="${SS}\"y_max_box_selected boolean $YMAX\", "
SS="${SS}\"z_max_box_selected boolean $ZMAX\", "
SS="${SS}\"do_smart_movement boolean false\", "
SS="${SS}\"threshold_intensity double 10.0\", "
SS="${SS}\"res_x double $Xres\", "
SS="${SS}\"res_y double $Yres\", "
SS="${SS}\"res_z double $Zres\", "

if [ $OS = 'cygwin' ]; then
    # cygwin on windows requires special path handling
	SS="${SS}\"mtxFileDirectory string $(cygpath -w $PARENT_DIR/MTX/)\", "
	SS="${SS}\"spimAFileDir string $(cygpath -w $PARENT_DIR/SPIMA/)\", "
	SS="${SS}\"spimBFileDir string $(cygpath -w $PARENT_DIR/SPIMB/)\", "
	SS="${SS}\"prefusionBaseDirString string $(cygpath -w $PARENT_DIR/PrefusionBase/)\", "
	SS="${SS}\"prefusionTransformDirString string $(cygpath -w $PARENT_DIR/PrefusionTransform/)\", "
	SS="${SS}\"deconvDirString string $(cygpath -w $PARENT_DIR/Deconvolution/)\", "
else
	SS="${SS}\"mtxFileDirectory string $PARENT_DIR/MTX\", "
	SS="${SS}\"spimAFileDir string $PARENT_DIR/SPIMA\", "
	SS="${SS}\"spimBFileDir string $PARENT_DIR/SPIMB\", "
	SS="${SS}\"prefusionBaseDirString string ${PARENT_DIR}/PrefusionBase/\", "
	SS="${SS}\"prefusionTransformDirString string ${PARENT_DIR}/PrefusionTransform/\", "
	SS="${SS}\"deconvDirString string ${PARENT_DIR}/Deconvolution/\", "
fi
SS="${SS}\"baseImage string $BASE\", "
SS="${SS}\"base_rotation int -1\", "
SS="${SS}\"transform_rotation int $TRANS_ROT\", "
SS="${SS}\"concurrent_num int $NPROC\", "
SS="${SS}\"mode_num int 0\", "
SS="${SS}\"save_type string Tiff\", "
SS="${SS}\"do_deconv boolean $DCON_BOOL\", "
SS="${SS}\"min_threshold float 0.0\", "
SS="${SS}\"sliding_window int -1\", "
SS="${SS}\"deconv_platform int $DCON_PLATFORM\", "
SS="${SS}\"deconv_show_results boolean false\", "
SS="${SS}\"deconvolution_method int 1\", "
SS="${SS}\"deconv_iterations int 10\", "
SS="${SS}\"deconv_sigmaA list_float $DCON_SIGA_X,$DCON_SIGA_Y,$DCON_SIGA_Z\", "
SS="${SS}\"deconv_sigmaB list_float $DCON_SIGB_Z,$DCON_SIGB_Y,$DCON_SIGB_X\", "
SS="${SS}\"use_deconv_sigma_conversion_factor boolean true\", "
SS="${SS}\"x_move int 0\", "
SS="${SS}\"y_move int 0\", "
SS="${SS}\"z_move int 0\""
#if [[ -z $FUSION_RANGE ]]; then
#    SS="${SS})"
#else
SS="${SS}, \"fusion_range string $FUSION_RANGE\")"
#fi

# write the MIPAV script (called fusScript) to the parent directory
R=$(echo "$FUSION_RANGE" | tr , _)
SCRIPT_PATH=$PARENT_DIR/fusScript${R}
echo $SS > $SCRIPT_PATH

echo Running MIPAV fusion on $OS with $NPROC concurrent processes...

# this actually launches mipav and executes the fusion
if [ $OS = 'cygwin' ]; then
	/cygdrive/c/Program\ Files/mipav/mipav.bat -s $(cygpath -w $SCRIPT_PATH) -hide
else
    # if no graphical environment is detected, as on many clusters, you must start a virtual frame buffer
    # I use Xvfb or xvfb-run for this
    # more info here: http://elementalselenium.com/tips/38-headless
    if [[ -z $DISPLAY ]]; then
        /home/tjl10/usr/bin/Xvfb :2 &
        pidToKill=$!
        DISPLAY=:2 $MIPAV -s $SCRIPT_PATH -hide
        kill $pidToKill
        rm -f $SCRIPT_PATH
    else 
        # this is what would be used on a local environment where the $DISPLAY environmental variable is detected
        $MIPAV -s $SCRIPT_PATH -hide
    fi
fi

