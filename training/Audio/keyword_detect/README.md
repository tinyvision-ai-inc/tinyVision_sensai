# **Keyphrase Detection Training using TensorFlow 1.14.0**

This repo provides the tools for training a neural network model for keyword/keyphrase detection. Some of the Python codes have been borrowed from the demo package released by Lattice Semiconductor regarding keyphrase detection using their ICE40 FPGA boards.

The model trained using these tools could be deployed to Lattice Semiconductor ICE40 5K LUT FPGA boards. Note that the trained neural network model has to be converted to binary file containing weights and activations using a proprietary software made available by Lattice Semiconductors. **In order to create the binary files using Lattice Semiconductor softwares, it is mandatory that the neural network model be created using TensorFlow versions of 1.14.0 or earlier.**

The python codes in this repo have been tested on Windows10 + Cygwin + Python3.6.8 

## Steps:
1. Create a virtual environment on your local machine and activate it, using the following commands:
~~~
virtualenv Keyphrase_Detection_VENV
cd ./Keyphrase_Detection_VENV
source ./Scripts/activate
~~~
   - If virtualenv is not installed on your machine, use the following command:
        ~~~
        pip3 install -U virtualenv
        ~~~
   - After installing virtualenv, go back to the above set of commands to create the Keyphrase_Detection_VENV.

2. Clone this repository and store it inside the folder corresponding to the virtual environment
~~~
git clone https://github.com/chatterjeesandipan/keyphrase_detection.git
cd ./keyphrase_detection
~~~

3. Install the necessary python packages using the requirements.txt file
~~~
pip3 install -r requirements.txt
~~~

4. Get the raw audio data (also known as Speech Commands) using the following command:
    - This step downloads the rawdata as a tarfile, unzips the tarfile and converts the sample rate of the audio files to 8000. 
    ~~~
    python audio_data_download.py --dataset=2
    ~~~
    
5. Open the config.sh file with an editor, for example NotePad++. 
    - In this file, mention the location of the data (sample rate converted) that will be used for training. For example, if you downloaded speech commands dataset 2:
    ~~~
    export DATA_DIR=../data/speech_commands_set_2_SR_8000/
    ~~~
    - Also, edit the "logs" folder to something that uniquely identifies your training session today, for example ./Logs_Jan_17_2020/. 
    ~~~
    export FILTER_TRAIN_DIR=./Logs_Jan_17_2020/set8_seven.filter
    export TRAIN_DIR=./Logs_Jan_17_2020/set_prefilter
    ~~~
    - Further, include all the keywords that are in the (sample rate converted) speech commands folder into the FILTER_TRAIN_KEYWORD list:
    ~~~
    export FILTER_TRAIN_KEYWORD="marvin,sheila,on,off,up,down,go,stop,left,right,\
    yes,learn,follow,visual,no,cat,dog,bird,tree,house,bed,wow,happy,zero,one,two,\
    three,four,five,six,seven,eight,nine,forward,backward"
    ~~~
    - Select a set of keywords that you want to train the neural network model for:
    ~~~
    export TRAIN_KEYWORD="left,right,forward,backward"
    ~~~
    - Leave the rest of the options as they are.
    
6. Open the train_filter.sh file with an editor, say NotePad++:
    - Edit the --summaries_dir line to point to the same logs folder created above
    ~~~
    --summaries_dir=./Logs_Jan_17_2020/$FILTER_NET_ID
    ~~~
    - You may change the number of iterations and the corresponding learning rates as per choice. Note that these are not optimized values
    ~~~
    --how_many_training_steps=30000,10000,10000 \
    --learning_rate=0.01,0.005,0.001 \
    ~~~
    - You may have to change the batch_size depending on your local machine's capabilities. I am currently using a batch size of 128 and it works well on a 2 GB Nvidia GPU. 
    - Note that the silence_percentage and unknown_percentage need to be set around 5%
    ~~~
    --silence_percentage=5 \
    --unknown_percentage=5 \
    ~~~
    - It is recommended that the filter be trained for 50000 epochs
    
7. Make ./Training as your current directory and run the train_filter shell script
~~~
cd ./Training
./train_filter.sh
~~~

8. After the train_filter.sh has concluded training, open the train.sh script in an editor. Note that the train.sh script uses the checkpoint created by train_filter.sh, which looks like **tinyvgg_conv.ckpt-50000**
    - Edit the path of filter checkpoint; Pick the latest checkpoint (highest number) and substitute the XXXXX below with this ckeckpoint number 
    ~~~
    TRAIN_OPT="$TRAIN_OPT --set_prefilter=$FILTER_TRAIN_DIR/tinyvgg_conv.ckpt-XXXXX --lock_prefilter"
    ~~~
    - Edit the summaries_dir to point to the same logs directory as created above
    ~~~
    --summaries_dir=./Logs_Jan_17_2020/$NET_ID \
    ~~~
    - Edit the number of iterations (or epochs) and the corresponding learning rates. Its recommended to go for a total of 50000 epochs
    ~~~
    --how_many_training_steps=30000,10000,10000 
    --learning_rate=0.01,0.005,0.001 
    ~~~
    - You may have to change the batch size to suit your computer's capabilities. 
    - Note that the silence and the unknown percentages should be set to 100%
    ~~~
    --silence_percentage=100 \
    --unknown_percentage=100 \
    ~~~

9. Run the train shell script
~~~
./train.sh
~~~

10. The two steps take about 48 hours on my laptop (Intel i7, 16 GB RAM, Nvidia 960M 2GB). So sitback and relax. The training speed is not very high. Significant gains are expected if the training is performed on Colab. The Colab script for training keyphrase detection models will be uploaded soon to this repo.
