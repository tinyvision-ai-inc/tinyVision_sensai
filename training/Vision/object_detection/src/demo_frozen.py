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

import numpy as np
import tensorflow as tf

from utils import util
from utils.util import sparse_to_dense, bgr_to_rgb, bbox_transform, nms

IMAGE_WIDTH         = 224
IMAGE_HEIGHT        = 224
TOP_N_DETECTION     = 10
PROB_THRESH         = 0.005
NMS_THRESH          = 0.4
PLOT_PROB_THRESH    = 0.4
CLASSES             = 1
CLASS_NAMES         = ('person',)
#BGR_MEANS           = np.array([[[103.939, 116.779, 123.68]]])
BGR_MEANS           = np.array([[[0.0, 0.0, 0.0]]])
BATCH_SIZE          = 20


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
tf.app.flags.DEFINE_integer(
    'gpu', 1, """GPU selection.""")
tf.app.flags.DEFINE_string(
    'graph', './freeze_pb/frozen_graph.pb', """Frozen pb""")

def _draw_box(im, box_list, label_list, color=(128,0,128), cdict=None, form='center', scale=1):
  assert form == 'center' or form == 'diagonal', \
      'bounding box format not accepted: {}.'.format(form)

  for bbox, label in zip(box_list, label_list):

    if form == 'center':
      bbox = bbox_transform(bbox)

    xmin, ymin, xmax, ymax = [int(b)*scale for b in bbox]

    l = label.split(':')[0]
    if cdict and l in cdict:
      c = cdict[l]
    else:
      c = color

    cv2.rectangle(im, (xmin, ymin), (xmax, ymax), c, 1)
    font = cv2.FONT_HERSHEY_SIMPLEX
    cv2.putText(im, label, (max(1, xmin-10), ymax+10), font, 0.3, c, 1) #<--------------------


def load_graph(filename):
  """Unpersists graph from file as default graph."""
  with tf.gfile.FastGFile(filename, 'rb') as f:
    graph_def = tf.GraphDef()
    graph_def.ParseFromString(f.read())
    tf.import_graph_def(graph_def, name='')


def filter_prediction(boxes, probs, cls_idx):
  """Filter bounding box predictions with probability threshold and
  non-maximum supression.

  Args:
    boxes: array of [cx, cy, w, h].
    probs: array of probabilities
    cls_idx: array of class indices
  Returns:
    final_boxes: array of filtered bounding boxes.
    final_probs: array of filtered probabilities
    final_cls_idx: array of filtered class indices
  """

  if TOP_N_DETECTION < len(probs) and TOP_N_DETECTION > 0:
    order = probs.argsort()[:-TOP_N_DETECTION-1:-1]
    probs = probs[order]
    boxes = boxes[order]
    cls_idx = cls_idx[order]
  else:
    filtered_idx = np.nonzero(probs>PROB_THRESH)[0]
    probs = probs[filtered_idx]
    boxes = boxes[filtered_idx]
    cls_idx = cls_idx[filtered_idx]

  final_boxes = []
  final_probs = []
  final_cls_idx = []

  for c in range(CLASSES):
    idx_per_class = [i for i in range(len(probs)) if cls_idx[i] == c]
    keep = util.nms(boxes[idx_per_class], probs[idx_per_class], NMS_THRESH)
    for i in range(len(keep)):
      if keep[i]:
        final_boxes.append(boxes[idx_per_class[i]])
        final_probs.append(probs[idx_per_class[i]])
        final_cls_idx.append(c)
  return final_boxes, final_probs, final_cls_idx


def video_demo():
  """Detect videos."""

  cap = cv2.VideoCapture(FLAGS.input_path)
  fps = cap.get(cv2.CAP_PROP_FPS)
  width  = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
  height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)

  # Define the codec and create VideoWriter object
  out_name = FLAGS.input_path.split('/')[-1:][0]
  out_name = out_name.split('.')[0]
  out_name = os.path.join(FLAGS.out_dir, 'det_'+out_name+'.x264')
  fourcc = cv2.VideoWriter_fourcc(*'X264')
  video = cv2.VideoWriter(out_name, fourcc, fps, (int(width), int(height)), True)

  assert FLAGS.demo_net == 'squeezeDet' or FLAGS.demo_net == 'squeezeDet+', \
      'Selected nueral net architecture not supported: {}'.format(FLAGS.demo_net)

  load_graph(FLAGS.graph)

  with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:
    times = {}
    count = 0
    det_last = [0, 0, 0]
    top_last = [0, 0, 0]

    while cap.isOpened():
      t_start = time.time()
      count += 1

      # Load images from video and crop
      images = []
      frame_buf = []
      for i in range(BATCH_SIZE):
        ret, frame = cap.read()
        frame_buf.append(frame)
        if ret==True:
          frame = frame[:,:,::-1]
          # crop frames
          orig_h, orig_w, _ = [float(v) for v in frame.shape]
          scale_h = int(orig_h / IMAGE_HEIGHT)
          scale_w = int(orig_w / IMAGE_WIDTH)
          up_scale = min(scale_h, scale_w)
   
          y_start = int(orig_h/2 - IMAGE_HEIGHT*up_scale/2)
          x_start = int(orig_w/2 - IMAGE_WIDTH*up_scale/2)
          im = frame[y_start:y_start+IMAGE_HEIGHT*up_scale, x_start:x_start+IMAGE_WIDTH*up_scale]
          im = cv2.resize(im, (IMAGE_WIDTH, IMAGE_HEIGHT))
          im_input = im.astype(np.float32) - BGR_MEANS
   
        else:
          print('Done')
          break
   
        images.append(im_input)

      t_reshape = time.time()
      times['reshape']= t_reshape - t_start

      np_images = np.array(images)

      g_boxes = sess.graph.get_tensor_by_name('bbox/trimming/bbox:0')
      g_probs = sess.graph.get_tensor_by_name('probability/score:0')
      g_class = sess.graph.get_tensor_by_name('probability/class_idx:0')

      g_image_input = sess.graph.get_tensor_by_name('batch:0')

      # Detect
      det_boxes, det_probs, det_class = sess.run(
          [g_boxes, g_probs, g_class],
          feed_dict={g_image_input:np_images})

      t_detect = time.time()
      times['detect'] = t_detect - t_reshape

      print(det_boxes.shape)
      
      for i in range(BATCH_SIZE):
        # Extract class only - mine :)
        top_idx = det_probs[i].argsort()[:-2:-1]
        top_prob = det_probs[i][top_idx]
        top_class = det_class[i][top_idx]
        if(top_prob > PLOT_PROB_THRESH):
            new_top_last = [top_last[1], top_last[2], 1]
        else:
            new_top_last = [top_last[1], top_last[2], 0]
        # End of mine
   
        # Filter
        final_boxes, final_probs, final_class = filter_prediction(
            det_boxes[i], det_probs[i], det_class[i])
   
        keep_idx    = [idx for idx in range(len(final_probs)) \
                          if final_probs[idx] > PLOT_PROB_THRESH]
   
        frame = frame_buf[i]
        im_show = frame[y_start:y_start+IMAGE_HEIGHT*up_scale, x_start:x_start+IMAGE_WIDTH*up_scale] 
   
        if(len(keep_idx) != 0):
            final_boxes = [final_boxes[idx] for idx in keep_idx]
            final_probs = [final_probs[idx] for idx in keep_idx]
            final_class = [final_class[idx] for idx in keep_idx]
   
            t_filter = time.time()
            times['filter']= t_filter - t_detect
   
            # Draw boxes
            print(final_boxes)
   
            if(sum(det_last) != 0): # filter
              _draw_box(
                im_show, final_boxes,
                [CLASS_NAMES[idx]+': (%.2f)'% prob \
                  for idx, prob in zip(final_class, final_probs)], scale=up_scale
              )
   
        im_show_exp = im_show
        frame[y_start:y_start+IMAGE_HEIGHT*up_scale, x_start:x_start+IMAGE_WIDTH*up_scale] = im_show_exp
        cv2.rectangle(frame, (x_start, y_start), (x_start+IMAGE_WIDTH*up_scale, y_start+IMAGE_HEIGHT*up_scale), 
            (255,0,255), 4)
   
        if(top_prob > PLOT_PROB_THRESH and sum(top_last) != 0):
            font = cv2.FONT_HERSHEY_SIMPLEX
            print('top_class=', top_class[0])
            label = CLASS_NAMES[top_class[0]] #+': (%.2f)'% top_prob[0]
            label = label[-2:]
            cv2.putText(frame, label, (x_start, y_start), font, 1.5, (0,255,0), 2)
   
        cv2.imshow('video', frame)
        video.write(frame)

        new_det_last = [det_last[1], det_last[2], len(keep_idx)]
        det_last = new_det_last
        top_last = new_top_last
        if cv2.waitKey(1) & 0xFF == ord('q'):
          break

  # Release everything if job is finished
  cap.release()
  video.release()
  cv2.destroyAllWindows()


def image_demo():
  """Detect image."""

  assert FLAGS.demo_net == 'squeezeDet' or FLAGS.demo_net == 'squeezeDet+', \
      'Selected nueral net architecture not supported: {}'.format(FLAGS.demo_net)

  load_graph(FLAGS.graph)

  with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:

    for f in glob.iglob(FLAGS.input_path):
      print('file name:'+f)
      im = cv2.imread(f)
      im = im.astype(np.float32, copy=False)

      im = cv2.resize(im, (IMAGE_WIDTH, IMAGE_HEIGHT), interpolation=cv2.INTER_AREA)
      orig_h, orig_w, _ = [float(v) for v in im.shape]
      im -= BGR_MEANS

      images = []
      for i in range(BATCH_SIZE):
          images.append(im)

      np_images = np.array(images)

      g_boxes = sess.graph.get_tensor_by_name('bbox/trimming/bbox:0')
      g_probs = sess.graph.get_tensor_by_name('probability/score:0')
      g_class = sess.graph.get_tensor_by_name('probability/class_idx:0')

      g_image_input = sess.graph.get_tensor_by_name('batch:0')

      # Detect
      det_boxes, det_probs, det_class = sess.run(
          [g_boxes, g_probs, g_class],
          feed_dict={g_image_input:np_images})

      # Filter
      final_boxes, final_probs, final_class = filter_prediction(
          det_boxes[0], det_probs[0], det_class[0])

      keep_idx    = [idx for idx in range(len(final_probs)) \
                        if final_probs[idx] > PLOT_PROB_THRESH]
      final_boxes = [final_boxes[idx] for idx in keep_idx]
      final_probs = [final_probs[idx] for idx in keep_idx]
      final_class = [final_class[idx] for idx in keep_idx]

      # Draw boxes
      print('# of final boxes=', len(keep_idx))
      _draw_box(
          im, final_boxes,
          [CLASS_NAMES[idx]+': (%.2f)'% prob \
              for idx, prob in zip(final_class, final_probs)]
      )

      file_name = os.path.split(f)[1]
      print(file_name)
      out_file_name = os.path.join(FLAGS.out_dir, 'out_'+file_name)

      cv2.imwrite(out_file_name, im+BGR_MEANS)
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
