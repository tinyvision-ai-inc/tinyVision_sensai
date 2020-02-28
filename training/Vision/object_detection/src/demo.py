# Author: Bichen Wu (bichen@berkeley.edu) 08/25/2016

"""SqueezeDet Demo.

In image detection mode, for a given image, detect objects and draw bounding
boxes around them. In video detection mode, perform real-time detection on the
video stream.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import cv2
import time
import sys
import os
import glob
import skvideo.io
#import matplotlib.pyplot as plt
#import matplotlib.image as mpimg


import numpy as np
import tensorflow as tf

from config import *
from train import _draw_box
from nets import *
#from utils.util import sparse_to_dense, bgr_to_rgb, bbox_transform


FLAGS = tf.app.flags.FLAGS

tf.app.flags.DEFINE_string(
    'mode', 'image', """'image' or 'video'.""")
tf.app.flags.DEFINE_string(
    'checkpoint', './data/model_checkpoints/squeezeDet/model.ckpt-87000',
    """Path to the model parameter file.""")
tf.app.flags.DEFINE_string(
    'input_path', './data/sample.png',
    """Input image or video to be detected. Can process glob input such as """
    """./data/00000*.png.""")
tf.app.flags.DEFINE_string(
    'out_dir', './data/out/', """Directory to dump output image or video.""")
tf.app.flags.DEFINE_string(
    'demo_net', 'squeezeDet', """Neural net architecture.""")
#tf.app.flags.DEFINE_integer(
#    'gpu', 1, """GPU selection.""")


def video_demo():
  """Detect videos."""

  cap = cv2.VideoCapture(FLAGS.input_path)
  fps = cap.get(cv2.CAP_PROP_FPS)
  width  = cap.get(cv2.CAP_PROP_FRAME_WIDTH)   # float
  height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT) # float

  out_name = FLAGS.input_path.split('/')[-1:][0]
  out_name = out_name.split('.')[0]
  #out_name = os.path.join(FLAGS.out_dir, 'det_'+out_name+'.avi')
  out_name = os.path.join(FLAGS.out_dir, 'det_'+out_name+'.x264')
  #print(out_name)
  #fourcc = cv2.VideoWriter_fourcc(*'XVID')
  fourcc = cv2.VideoWriter_fourcc(*'X264')
  video = cv2.VideoWriter(out_name, fourcc, fps, (int(width), int(height)), True)
  #cap = skvideo.io.VideoCapture(FLAGS.input_path)

  # Define the codec and create VideoWriter object
  # fourcc = cv2.cv.CV_FOURCC(*'XVID')
  # fourcc = cv2.cv.CV_FOURCC(*'MJPG')
  # in_file_name = os.path.split(FLAGS.input_path)[1]
  # out_file_name = os.path.join(FLAGS.out_dir, 'out_'+in_file_name)
  # out = cv2.VideoWriter(out_file_name, fourcc, 30.0, (375,1242), True)
  # out = VideoWriter(out_file_name, frameSize=(1242, 375))
  # out.open()

  assert FLAGS.demo_net == 'squeezeDet' or FLAGS.demo_net == 'squeezeDet+', \
      'Selected nueral net architecture not supported: {}'.format(FLAGS.demo_net)

  with tf.Graph().as_default():
    # Load model
    if FLAGS.demo_net == 'squeezeDet':
      mc = kitti_squeezeDet_config()
      mc.BATCH_SIZE = 1
      mc.IS_TRAINING = False
      # model parameters will be restored from checkpoint
      mc.LOAD_PRETRAINED_MODEL = False
      #model = SqueezeDet(mc, FLAGS.gpu)
      model = SqueezeDet(mc, gpu_id=1)
    elif FLAGS.demo_net == 'squeezeDet+':
      mc = kitti_squeezeDetPlus_config()
      mc.BATCH_SIZE = 1
      mc.LOAD_PRETRAINED_MODEL = False
      mc.IS_TRAINING = False
      model = SqueezeDetPlus(mc, FLAGS.gpu)

    saver = tf.train.Saver(model.model_params)

    with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:
      saver.restore(sess, FLAGS.checkpoint)

      # ==============================================================================
      # Store Graph
      # ==============================================================================
      tf.train.write_graph(sess.graph_def, "/tmp/tensorflow", "test.pb", as_text=False)
      tf.train.write_graph(sess.graph_def, "/tmp/tensorflow", "test.pbtx", as_text=True)
      # ==============================================================================
      print("Graph store is done")
      times = {}
      count = 0
      det_last = [0, 0, 0]
      top_last = [0, 0, 0]
      while cap.isOpened():
        t_start = time.time()
        count += 1
        # Load images from video and crop
        ret, frame = cap.read()
        print(ret)
        if ret:
          frame = frame[:,:,::-1] # <--- convert to BGR
          orig_h, orig_w, _ = [float(v) for v in frame.shape]
          #print(orig_h, orig_w)
          y_start = int(orig_h/2-mc.IMAGE_HEIGHT*2/2)
          x_start = int(orig_w - mc.IMAGE_WIDTH*2)
          im = frame[y_start:y_start+mc.IMAGE_HEIGHT*2, x_start:x_start+mc.IMAGE_WIDTH*2]
          #im = im.astype(np.float32)
          #im = frame.astype(np.float32)
      #im = im[y_start:y_start+mc.IMAGE_HEIGHT, x_start:x_start+mc.IMAGE_WIDTH]
          im = cv2.resize(im, (mc.IMAGE_WIDTH, mc.IMAGE_HEIGHT))
          im_input = im.astype(np.float32) - mc.BGR_MEANS # <---------------------------------------------------------------------!!!!!!

    #im = cv2.resize(im, (mc.IMAGE_WIDTH*1, mc.IMAGE_HEIGHT*1))
    #im_gray = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY) # gray color instead of RGB
    #im_input = im_gray - np.array([[[128]]])
    #im_input = im_gray
    #im_input = im_input.reshape((mc.IMAGE_HEIGHT, mc.IMAGE_WIDTH, 1))
        else:
          print('Done')
          break

        t_reshape = time.time()
        times['reshape']= t_reshape - t_start

        # Detect
        det_boxes, det_probs, det_class = sess.run(
            [model.det_boxes, model.det_probs, model.det_class],
            feed_dict={model.image_input:[im_input]})

        t_detect = time.time()
        times['detect']= t_detect - t_reshape
        
        # Extract class only - mine :)
    top_idx = det_probs[0].argsort()[:-2:-1] # top probability only
    #print("top_idx=", top_idx)
    top_prob = det_probs[0][top_idx]
    #print("top_prob=", top_prob)
    top_class = det_class[0][top_idx]
    #print('top class=', top_class)
    if(top_prob > mc.PLOT_PROB_THRESH):
        new_top_last = [top_last[1], top_last[2], 1]
    else:
        new_top_last = [top_last[1], top_last[2], 0]
        # End of mine

        # Filter
        final_boxes, final_probs, final_class = model.filter_prediction(
            det_boxes[0], det_probs[0], det_class[0])

        keep_idx    = [idx for idx in range(len(final_probs)) \
                          if final_probs[idx] > mc.PLOT_PROB_THRESH]

    frame = frame[:,:,::-1]
    #im_show_i = im[:,:,::-1] # convert back to RGB
    #im_show   = im_show_i.astype(np.uint8).copy() # to solve known bug of cv2
    im_show = frame[y_start:y_start+mc.IMAGE_HEIGHT*2, x_start:x_start+mc.IMAGE_WIDTH*2] 
    if(len(keep_idx) != 0):
        final_boxes = [final_boxes[idx] for idx in keep_idx]
        final_probs = [final_probs[idx] for idx in keep_idx]
        final_class = [final_class[idx] for idx in keep_idx]
        t_filter = time.time()
        times['filter']= t_filter - t_detect
        # Draw boxes
        # TODO(bichen): move this color dict to configuration file
        cls2clr = {
        'car': (255, 191, 0),
        'cyclist': (0, 191, 255),
        'pedestrian':(255, 0, 191)
        }

        if(sum(det_last) != 0): # filter
        #if(True): # filter
          _draw_box(
              im_show, final_boxes,
              [mc.CLASS_NAMES[idx]+': (%.2f)'% prob \
              for idx, prob in zip(final_class, final_probs)], scale=2
              )

        #t_draw = time.time()
        #times['draw']= t_draw - t_filter
        #im_show_exp = cv2.resize(im_show, (mc.IMAGE_WIDTH*2, mc.IMAGE_HEIGHT*2))
    im_show_exp = im_show
    frame[y_start:y_start+mc.IMAGE_HEIGHT*2, x_start:x_start+mc.IMAGE_WIDTH*2] = im_show_exp
    cv2.rectangle(frame, (x_start, y_start), (x_start+mc.IMAGE_WIDTH*2, y_start+mc.IMAGE_HEIGHT*2), 
        (255,0,255), 4)

    if(top_prob > mc.PLOT_PROB_THRESH and sum(top_last) != 0):
        font = cv2.FONT_HERSHEY_SIMPLEX
        print('top_class=', top_class[0])
        label = mc.CLASS_NAMES[top_class[0]] #+': (%.2f)'% top_prob[0]
        label = label[-2:]
        cv2.putText(frame, label, (x_start, y_start), font, 1.5, (0,255,0), 2)

        #cv2.imshow('video', im_show) # <--- RGB input
        cv2.imshow('video', frame) # <--- RGB input
    video.write(frame)
    if(len(keep_idx) !=0 and sum(det_last) != 0):
    #if(len(keep_idx) !=0):
        for x in range(10): # slow down in demo video
            video.write(frame)
        #cv2.imwrite(out_im_name, im_show) # <--- BGR input

        #times['total']= time.time() - t_start

        # time_str = ''
        # for t in times:
        #   time_str += '{} time: {:.4f} '.format(t[0], t[1])
        # time_str += '\n'
        #time_str = 'Total time: {:.4f}, detection time: {:.4f}, filter time: '\
        #           '{:.4f}'. \
        #    format(times['total'], times['detect'], times['filter'])

        #print (time_str)
    #if((len(keep_idx) != 0 and det_last != 0) or True):
    #    cv2.waitKey()
            if cv2.waitKey(5) & 0xFF == ord('q'):
                break
    new_det_last = [det_last[1], det_last[2], len(keep_idx)]
    det_last = new_det_last
    top_last = new_top_last
    #print(det_last)
  # Release everything if job is finished
  cap.release()
  video.release()
  # out.release()
  cv2.destroyAllWindows()


def image_demo():
  """Detect image."""

  assert FLAGS.demo_net == 'squeezeDet' or FLAGS.demo_net == 'squeezeDet+', \
      'Selected nueral net architecture not supported: {}'.format(FLAGS.demo_net)

  with tf.Graph().as_default():
    # Load model
    if FLAGS.demo_net == 'squeezeDet':
      mc = kitti_squeezeDet_config()
      mc.BATCH_SIZE = 1
      # model parameters will be restored from checkpoint
      mc.LOAD_PRETRAINED_MODEL = False
      mc.IS_TRAINING = False
      #model = SqueezeDet(mc, FLAGS.gpu)
      model = SqueezeDet(mc, gpu_id=0)

    saver = tf.train.Saver(model.model_params)

    with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:
      saver.restore(sess, FLAGS.checkpoint)

      if True:
        # ==============================================================================
        # Store Graph
        # ==============================================================================
        tf.train.write_graph(sess.graph_def, "./logs/tensorflow", "test.pb", as_text=False)
        tf.train.write_graph(sess.graph_def, "./logs/tensorflow", "test.pbtxt", as_text=True)
        # ==============================================================================
        print('graph was written in pbtxt udner logs/tensorflow')
      print(FLAGS.input_path)
      for f in glob.iglob(FLAGS.input_path):
        print('file name:'+f)
        im = cv2.imread(f) # <---------------------------- BGR format
        im = im.astype(np.float32, copy=False)

        #im = cv2.resize(im, (mc.IMAGE_WIDTH, mc.IMAGE_HEIGHT), interpolation=cv2.INTER_AREA)
        orig_h, orig_w, _ = [float(v) for v in im.shape]
        org_im = im.copy()
        im -= mc.BGR_MEANS # <---------------------------------------------------------------------!!!!!!
        im /= 128.0

        np.set_printoptions(threshold=np.inf)#'nan')


        # Detect
        det_boxes, det_probs, det_class, conv12 = sess.run(
            [model.det_boxes, model.det_probs, model.det_class, model.preds],
            feed_dict={model.image_input:[im]})
        conv12 = np.reshape(conv12, (1,42,4,4))
        #print('shape of conv12={}'.format(conv12.shape))
        #print('conv12={}'.format(conv12))
        #print('det_boxes={}'.format(det_boxes))
        #print('det_probs={}'.format(det_probs))

        # Filter
        final_boxes, final_probs, final_class = model.filter_prediction(
            det_boxes[0], det_probs[0], det_class[0])

        keep_idx    = [idx for idx in range(len(final_probs)) \
                          if final_probs[idx] > mc.PLOT_PROB_THRESH]
        final_boxes = [final_boxes[idx] for idx in keep_idx]
        final_probs = [final_probs[idx] for idx in keep_idx]
        final_class = [final_class[idx] for idx in keep_idx]

        print('keep_idx={}'.format(keep_idx))
        print('final_boxes={}'.format(final_boxes))
        print('final_probs={}'.format(final_probs))

        # TODO(bichen): move this color dict to configuration file
        '''
        cls2clr = {
            'car': (255, 191, 0),
            'cyclist': (0, 191, 255),
            'pedestrian':(255, 0, 191)
        }
        '''

        # Draw boxes
        print('# of final boxes=', len(keep_idx))
        _draw_box(
            #im_gray, final_boxes,
            org_im, final_boxes,
            [mc.CLASS_NAMES[idx]+': (%.2f)'% prob \
                for idx, prob in zip(final_class, final_probs)] #,
            #cdict=cls2clr,
        )

        file_name = os.path.split(f)[1]
        out_file_name = os.path.join(FLAGS.out_dir, 'out_'+file_name)

        cv2.imwrite(out_file_name, org_im) # <----- BGR format
        #cv2.imwrite(out_file_name, im_gray) # <----- BGR format
        print ('Image detection output saved to {}'.format(out_file_name))


def main(argv=None):
  if not tf.gfile.Exists(FLAGS.out_dir):
    tf.gfile.MakeDirs(FLAGS.out_dir)
  if FLAGS.mode == 'image':
    image_demo()
  else:
    video_demo()

if __name__ == '__main__':
    tf.app.run()
