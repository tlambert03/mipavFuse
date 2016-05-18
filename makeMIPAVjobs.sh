#!/bin/bash

# divide SPIM dataset into multiple different jobs and start the jobs with the job scheduler on the cluster

function Usage()
{
cat <<-ENDOFMESSAGE

$0 [OPTION] REQ1 REQ2

options:

    -h --help     display this message
	-n --ncores   number of cores per job (default is 4)
	-f --files    number of files per core (determines run time, default is 1)
	-b --base     base image (transform TO this image... SPIMB by default)
    -z --zstep    Zstep size (default is )

    These are only necessary if you don't want to process the whole dataset
    --begin    first timepoint to process
	--end      last timepoint to process

ENDOFMESSAGE
    exit 1
}

function Die()
{
    echo "$*"
    exit 1
}

#defaults
BASE=SPIMB
nCoresPerJob=4
nFilesPerCore=1
Zres=0.5

function GetOpts() {
    branch=""
    argv=()
    while [ $# -gt 0 ]
    do
        opt=$1
        shift
        case ${opt} in
            -n|--ncores)
                if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                nCoresPerJob="$1"
                shift
                ;;
            -f|--files)
                if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                nFilesPerCore="$1"
                shift
                ;;
            --begin)
                if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                BEGIN="$1"
                shift
                ;;
            --end)
                if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
                    Die "The ${opt} option requires an argument."
                fi
                END="$1"
                shift
                ;;
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

            # these options are not yet implemented... instead the mipavFuse file will determine the defaults here
            # the ability to adjust these parameters can be added to the job-scheduling script if desired...
            -x|--xpix)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                Xres="$1"
                shift ;;
            -y|--ypix)
                if [ $# -eq 0 -o "${1:0:1}" = "-" -o "${1:0:1}" = "/" ]; then Die "The ${opt} option requires an argument."; fi
                Yres="$1"
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

# make new directories for mtx and joblog files
[ -d $PARENT_DIR/joblogs ] || mkdir $PARENT_DIR/joblogs
[ -d $PARENT_DIR/MTX ] || mkdir $PARENT_DIR/MTX

# change this to the path of your mipavFuse script on your cluster
MIPAVRUN=/home/tjl10/mipavFuse.sh

# this part tries to determine how many timepoints there are in the dataset
# so as to break them up evenly into the appropriate number of jobs
fileType=.tif
nFilesPerJob=$[nFilesPerCore * $nCoresPerJob]
nFiles=$(ls -l $PARENT_DIR/SPIMA/*$fileType | grep -v ^l | wc -l)
nFiles=$[nFiles]
firstFile=$(ls $PARENT_DIR/SPIMA | sort -n | head -1)
firstFile=${firstFile%.*}
firstNumber=$(echo $firstFile | tail -c 2)

# first number not working yet...
[ ${BEGIN} ] || BEGIN=$firstNumber  # or BEGIN=0
[ ${END} ] || END=$[nFiles + $firstNumber -1]
counter=$BEGIN
while [ $[counter + $nFilesPerJob - 1] -le $END ]; do
    start=$counter
    finish=$[start + $nFilesPerJob - 1]
    counter=$[counter + $nFilesPerJob]
    # this is the line that actually starts the jobs, and will likely be the line that requires the most editing
    # change as needed to use the syntax appropraite for your job scheduler
    # note, you also need to change the line in the last conditional below (line ~244)
	bsub -q short -W 8:00 -R "rusage[mem=10000]" -o $PARENT_DIR/joblogs/job${start}-${finish}.out -J FUS$start-$finish -n $nCoresPerJob $MIPAVRUN -r $start-$finish -n $nCoresPerJob -b $BASE -z $Zres $PARENT_DIR
done

# when the number of files doesn't evenly divide into the number of cores per job, this starts the last job
if [ $[counter + $firstNumber] -le $END ]; then
    bsub -q short -W 8:00 -R "rusage[mem=10000]" -o $PARENT_DIR/joblogs/job${counter}-${END}.out -J FUS$counter-$END -n $nCoresPerJob $MIPAVRUN -r $counter-$END -n $nCoresPerJob -b $BASE -z $Zres $PARENT_DIR
fi