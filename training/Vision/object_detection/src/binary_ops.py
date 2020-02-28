from __future__ import absolute_import
import tensorflow.keras.backend as K
import tensorflow.compat.v1 as tf

def round_through(x):
    rounded = K.round(x)
    return x + K.stop_gradient(rounded - x)

def _hard_sigmoid(x):
    x = (0.5 * x) + 0.50001
    return tf.clip_by_value(x, 0, 1)

def binary_tanh(x): # activation binarization to 1 and 0
    #return 2 * round_through(_hard_sigmoid(x)) - 1
    return round_through(_hard_sigmoid(x))

def binarize(W): # weight binarization to 1 and -1
    #Wb = binary_tanh(W)
    #return Wb
    return 2 * round_through(_hard_sigmoid(W)) - 1

def lin_8b_quant(w, min_rng=-0.5, max_rng=0.5):
    min_clip = tf.math.rint(min_rng*256/(max_rng-min_rng))
    max_clip = tf.math.rint(max_rng*256/(max_rng-min_rng))

    wq = 256.0 * w / (max_rng - min_rng)              # to expand [min, max] to [-128, 128]
    wq = tf.math.rint(wq)                                  # integer (quantization)
    wq = tf.clip_by_value(wq, min_clip, max_clip)     # fit into 256 linear quantization
    wq = wq / 256.0 * (max_rng - min_rng)             # back to quantized real number, not integer
    wclip = tf.clip_by_value(w, min_rng, max_rng)     # linear value w/ clipping
    return wclip + tf.stop_gradient(wq - wclip)

