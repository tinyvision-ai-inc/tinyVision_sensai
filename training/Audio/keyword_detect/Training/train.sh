# 
# height = (clip_duration_ms - window_size_ms + window_stride_ms) / window_stride_ms
# clip_duration_ms = (height*window_stride_ms) + window_size_ms - window_stride_ms
# width  = dct_coefficient_count
#
# input: 98x40
# if win_size=30ms and win_stride=10ms, clip_duration_ms = 98*10+30-10 = 1000ms
#
# input: 2*32x32
# if win_size=32ms and win_stride=16ms, clip_duration_ms = 2*32*16+32-16 = 1040ms


# Export common configurations
. ./config.sh

# Start training from last checkpoint of filter training. Change directory if needed
TRAIN_OPT="$TRAIN_OPT --set_prefilter=$FILTER_TRAIN_DIR/tinyvgg_conv.ckpt-41000 --lock_prefilter \
--start_checkpoint=$TRAIN_DIR/tinyvgg_conv.ckpt-50000"

# Start training from given checkpoint. Uncomment below line and change checkpoint name.
#TRAIN_OPT="$TRAIN_OPT --start_checkpoint=$TRAIN_DIR/tinyvgg_conv.ckpt-200"

# Execute training
python train.py \
$COMMON_OPT \
--wanted_words=$TRAIN_KEYWORD \
--silence_percentage=100 \
--unknown_percentage=100 \
--how_many_training_steps=30000,10000,10000 \
--learning_rate=0.01,0.005,0.001 \
--batch_size=128 \
--train_dir=$TRAIN_DIR \
--data_dir=$DATA_DIR \
--training_mode=False \
--testing_mode=False \
--summaries_dir=./Local_Logs_Jan22_2020/$NET_ID \
$TRAIN_OPT
