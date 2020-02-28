#!/bin/bash

export GPUID=0
export NET="squeezeDet"
export EVAL_DIR="./logs/humancnt/"
export IMAGE_SET="val"

export TRAIN_DATA_DIR="/data/humancnt"

if [ $# -eq 0 ]
then
  echo "Usage: ./scripts/train.sh [options]"
  echo " "
  echo "options:"
  echo "-h, --help                show brief help"
  echo "-net                      (squeezeDet|squeezeDet+|vgg16|resnet50)"
  echo "-gpu                      gpu id"
  echo "-eval_dir                 directory to save logs"
  echo "-image_set                (train|val)"
  exit 0
fi

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "Usage: ./scripts/train.sh [options]"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-net                      (squeezeDet|squeezeDet+|vgg16|resnet50)"
      echo "-gpu                      gpu id"
      echo "-eval_dir                 directory to save logs"
      echo "-image_set                (train|val)"
      exit 0
      ;;
    -net)
      export NET="$2"
      shift
      shift
      ;;
    -gpu)
      export GPUID="$2"
      shift
      shift
      ;;
    -eval_dir)
      export EVAL_DIR="$2"
      shift
      shift
      ;;
    -image_set)
      export IMAGE_SET="$2"
      shift
      shift
      ;;
    *)
      break
      ;;
  esac
done

# =========================================================================== #
# command for squeezeDet:
# =========================================================================== #
python ./src/eval.py \
  --dataset=KITTI \
  --data_path=$TRAIN_DATA_DIR \
  --image_set=$IMAGE_SET \ # val
  --eval_dir="$EVAL_DIR/$IMAGE_SET" \ # /tmp/logs/squeezedet/val/
  --checkpoint_path="$EVAL_DIR/train" \ # /tmp/logs/squeezedet/train/
  --net=$NET \
  --gpu=$GPUID
