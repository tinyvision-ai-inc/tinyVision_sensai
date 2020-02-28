import tensorflow.compat.v1 as tf
import numpy as np
import os, sys, time, random
import matplotlib.pyplot as plt
from scipy import signal as sig

import argparse
parser = argparse.ArgumentParser(description="Visualize 1D convolution filters")
parser.add_argument("--train_logdir", help="Path to the training log directory")
args = parser.parse_args()

maindir = os.path.abspath(os.path.dirname(__file__))
os.chdir(maindir)
logdir = os.path.abspath(os.path.join(maindir, args.train_logdir, "set8_seven.filter"))
savedir = os.path.join(maindir, "Saved_Figures")
os.makedirs(savedir, exist_ok=True)

latest_ckpt = tf.train.latest_checkpoint(logdir)
tensors_ckpt = tf.train.list_variables(latest_ckpt)

### Select tensors related to the spectrogram generation
### The variable name is given by "freqconv"
freqconv = []
for tensor in tensors_ckpt:
    if tensor[0].__contains__("freqconv"):
        freqconv.append(tensor)

print("Tensors related to spectrogram generation: ", freqconv)

freq_weights = []
print("The tensors for spectrogram generation:")
for i in range(len(freqconv)):
    freq_weights.append(tf.train.load_variable(latest_ckpt, freqconv[i][0]))
    print("Tensor name: ", freqconv[i][0], "\t Shape: ", freqconv[i][1])

### Visualizing some weights
fig1, ax1 = plt.subplots(5, 1, sharex=True, sharey=True)
for i in range(5):
    filter = max(0, (64//4)*i - 1)
    ax1[i].plot(freq_weights[0][...,filter], 'k')
    ax1[i].annotate("Filter {}".format(filter+1), xy=(0, 4), ha='left', va='top', fontsize=12,\
                bbox=dict(facecolor='none', edgecolor='k', pad=2.0, linewidth=0.5))
plt.subplots_adjust(hspace=0.1)
fig1.text(0.025, 0.5, 'Weights for 1D Convolution', va='center', rotation='vertical',fontdict={'fontsize':14})
fig1.savefig(os.path.join(savedir, "Weights_1D_Conv.jpg"), dpi=300,\
    facecolor=None, edgecolor='w', pad_inches=0.05, format='jpg')

#### Generate spectrograms of the filters
fig2, ax2 = plt.subplots(5, 1, sharex=True, sharey=True)
for i in range(5):
    filter = max(0, (64//4)*i - 1)
    fwelch, psd = sig.welch(np.squeeze(freq_weights[0][...,filter]), fs=8000, nperseg=16, noverlap=15)
    ax2[i].plot(fwelch, psd/psd.max(), 'k')
    ax2[i].annotate("Filter {}".format(filter+1), xy=(3500, 0.8), ha='left', va='top', fontsize=12,\
                bbox=dict(facecolor='none', edgecolor='k', pad=2.0, linewidth=0.5))
plt.subplots_adjust(hspace=0.1)
fig2.text(0.5, 0.025, 'Frequency (Hz)', ha='center', fontdict={'fontsize':14, 'weight':'normal'})
fig2.text(0.05, 0.5, 'Normalized Welch PSD (arb. units)', va='center', rotation='vertical',fontdict={'fontsize':14})
fig2.savefig(os.path.join(savedir, "Welch_PSD_Weights_1D_Conv.jpg"), dpi=300,\
    facecolor=None, edgecolor='w', pad_inches=0.05, format='jpg')

