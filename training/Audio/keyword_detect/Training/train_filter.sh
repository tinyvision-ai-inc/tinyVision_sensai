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

# Start training from given checkpoint. Uncomment below line and change checkpoint name.
#TRAIN_OPT="$TRAIN_OPT --start_checkpoint=$FILTER_TRAIN_DIR/tinyvgg_conv.ckpt-200"

# Execute training
python train.py \
$COMMON_OPT \
--wanted_words=$FILTER_TRAIN_KEYWORD \
--silence_percentage=5 \
--unknown_percentage=5 \
--how_many_training_steps=30000,10000,10000 \
--learning_rate=0.01,0.005,0.001 \
--batch_size=96 \
--train_dir=$FILTER_TRAIN_DIR \
--data_dir=$DATA_DIR \
--summaries_dir=./Local_Logs_Jan22_2020/$FILTER_NET_ID \
--data_url= \
$TRAIN_OPT

# --data_url=http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz \