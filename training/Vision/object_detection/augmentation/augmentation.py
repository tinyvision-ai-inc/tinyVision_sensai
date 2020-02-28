#!/usr/bin/python
# -*- coding: utf-8 -*-
# python3 augmentation.py -h

from data_aug.data_aug import *
from data_aug.bbox_util import *
import cv2
import pickle as pkl
import numpy as np
import matplotlib.pyplot as plt
from numpy import array
import argparse
import sys
import shutil
from config import *
import os

ROOT_DIR      = ''

parser = argparse.ArgumentParser()                                      
parser.add_argument("--image_dir", type = str, default = "images", help = "Original image files")
parser.add_argument("--label_dir", type = str, default = "labels", help = "Original label files")
parser.add_argument("--out_image_dir", type = str, default = "augmented/aug_img")
parser.add_argument("--out_label_dir", type = str, default = "augmented/labels" )
args = parser.parse_args()
IMG_DIR = args.image_dir
LABEL_DIR = args.label_dir
AUG_IMG_DIR = args.out_image_dir
AUG_LABEL_DIR = args.out_label_dir


def make_dir():
    if not os.path.exists(IMG_DIR):
        print("Input Image direcory "+IMG_DIR+" Not found!!")
        sys.exit()
    if not os.path.exists(LABEL_DIR):
        print("Input Label direcory "+LABEL_DIR+" Not found!!")
        sys.exit()
    if not os.path.exists(AUG_IMG_DIR):
        os.makedirs(AUG_IMG_DIR)
    if not os.path.exists(AUG_LABEL_DIR):
        os.makedirs(AUG_LABEL_DIR)

Total_aug_cnt = 0
Person_cnt = 0

class Augmentation:

    def __init__(self):
        self.imglist = []
        self.labellist = []
        self.empty_cnt = 0
        self.ignored_labels_cnt = 0
    def listOfItemInDir(self, folerpath):
        if len(folerpath.strip()) == 0 or not os.path.exists(folerpath):
            raise ValueError('Error: listOfItemInDir(): folerpath path empty or invalid - "'
                              + folerpath + '"')
        itemlist = []
        for (rootdir, subdirs, files) in os.walk(folerpath):
            for itemname in files:
                filepath = rootdir + '/' + itemname
                itemlist.append(filepath)
        return itemlist

    def AugmentationOfImg(self, prefix):
        self.imglist = self.listOfItemInDir(IMG_DIR)
        self.labellist = self.listOfItemInDir(LABEL_DIR)
        op_count = 0
        for imagepath in self.imglist:
            img = cv2.imread(imagepath)[:, :, ::-1]  # OpenCV uses BGR channels
            # check Image is not Empty
            if img is None:
                print ('Image is empty')
                continue

            if img.shape[0]<Input_dict['resizeheight'] or img.shape[1]<Input_dict['resizewidth']:
              print("less then require resolution so ignored",img.shape)
              continue
            labelpath = LABEL_DIR + '/' + imagepath.split('/'
                    )[-1].split('.')[0] + '.txt'
            # Reading the image
            try:
                read = open(labelpath)
            except:
                print ('%s open failed''' % labelpath)
            bboxes = read.readlines()
            read.close()
            bboxes_array = []
            for bbox in bboxes:
                bbox = bbox.split(' ')[4:8]
                #bbox[3] = (bbox[-1])[:-1]			# To remove '\n' charactor from End of Line
                bboxes_array.append([float(i) for i in bbox])
            out_bboxes_array = array(bboxes_array)
            # Check either annotation file is Empty or Nor
            if out_bboxes_array.size == 0:
                print ('initial empty annotation file ', labelpath)
                continue
            transforms = Sequence(OperationsList)

            # Performing augmentation operation
            (outimg, outbboxes) = transforms(img, out_bboxes_array)
            if outbboxes.size == 0:
                self.empty_cnt = self.empty_cnt + 1
                print ('After operation bbox become empty for ',
                       imagepath, '- ', self.empty_cnt)
            else:
                index = -1
                index_list = []
                outbboxes_list = np.array(outbboxes.tolist())
                flag = 0
                for bbox in outbboxes:
                    index += 1
                    if ((bbox[3]- bbox[1] < 7) or (bbox[2]- bbox[0] < 7)):
                        print("ignoring image due to small bbox size for"+imagepath)
                        self.ignored_labels_cnt = self.ignored_labels_cnt + 1
                        flag = 1
                        break
                    else:
                        index_list.append(index)
                if flag == 1:
                    continue
                new_bbox_list = []
                if index_list == []:
                    continue
                else:
                    for i in index_list:
                        new_bbox_list.append(outbboxes_list[i])
                labelnamewithpath = AUG_LABEL_DIR + '/' + prefix \
                    + imagepath.split('/')[-1].split('.')[0] + '.txt'
                try:
                    write = open(labelnamewithpath, 'w+')
                except:
                    print ('%s writting failed' % labelnamewithpath)
                for bbox in new_bbox_list:
                    global Person_cnt
                    Person_cnt = Person_cnt + 1
                    s = ' '
                    updatedlabel = ['Person', '0.0', '0.0', '0.0'] 
                    for coord in bbox:
                        if coord < 0:
                            coord = 0.0
                        updatedlabel.append(str(coord))
                    s = s.join(updatedlabel)
                    write.write(s)
                    write.write('\n')
                write.close()

                OutImgloc = AUG_IMG_DIR + '/' + prefix \
                    + imagepath.split('/')[-1]
                outimg = cv2.cvtColor(outimg, cv2.COLOR_BGR2RGB)  #  saving back in RGB channels
                
                # Save augmented image to disk
                cv2.imwrite(OutImgloc, outimg)
                op_count = op_count + 1
                global Total_aug_cnt
                Total_aug_cnt = Total_aug_cnt + 1
        if self.empty_cnt > 0:
            print ('Total Number of empty bbox file till the operation- ', self.empty_cnt)
        if self.ignored_labels_cnt > 0:
        	print( 'Total Number ignored bboxes dueto it`s size- ', self.ignored_labels_cnt)
        print (
            'Valid augmented img count for above operation ',
            op_count,
            'out of ',
            len(self.imglist),
            'images, So discarded count is ',
            len(self.imglist) - op_count,
            )


    def CopyOrgImgLabel(self):
        org_imglist = self.listOfItemInDir(IMG_DIR)
        org_labellist = self.listOfItemInDir(LABEL_DIR)
        for imgpath in org_imglist:
            shutil.copy(IMG_DIR + '/' + imgpath.split('/')[-1],
                        AUG_IMG_DIR + '/' + imgpath.split('/')[-1])

            labelpathSrc = LABEL_DIR + '/' + imgpath.split('/')[-1].split('.')[0] + '.txt'
            #print("labelpathSrc -",labelpathSrc)
            try:
                readOrg = open(labelpathSrc)
            except:
                print ('%s open failed''' % labelpathSrc)

            bboxes = readOrg.readlines()
            readOrg.close()
            bboxes_array = []
            for bbox in bboxes:
                bbox = bbox.split(' ')[4:8]
                bbox[3] = (bbox[-1])[:-1]			# To remove '\n' charactor from End of Line
                bboxes_array.append([float(i) for i in bbox])
            out_bboxes_array = array(bboxes_array)
            labelpathDst = AUG_LABEL_DIR + '/' + imgpath.split('/')[-1].split('.')[0] + '.txt'
            try:
              write = open(labelpathDst, 'w+')
            except:
              print ('%s writting failed' % labelpathDst)
            for bbox in out_bboxes_array:
              s = ' '
              updatedlabel = ['Person', '0.0', '0.0', '0.0'] 
              for coord in bbox:
                if coord < 0:
                  coord = 0.0
                updatedlabel.append(str(coord))
              s = s.join(updatedlabel)
              write.write(s)
              write.write('\n')
            write.close()

if __name__ == '__main__':
    make_dir()
    print("\n|","-"*43,"|")
    print("|","Initial Configuration")
    print("|","-"*43,"|")
    for i in Input_dict:
      print("|",i ," "*(int(35)-len(i)),"|",Input_dict[i],"|")
    print("|","-"*43,"|\n")

    obj = Augmentation() 
    print ('\nCopying original images and labels ...')
    obj.CopyOrgImgLabel()
    print ('Done Coping\n')

    all_op = [
        'RandomHorizontalFlip',
        #'RandomScale',
        #'RandomRotate',
        #'RandomTranslate',
        #'RandomShear',
        #'Rotate',
        'Translate',
        #'Shear',
        #'GaussianFiltering',
        'RandomBrightness2_0',
        'RandomBrightness0_5',
        #'Resize'
    ]
    
    if 'Rotate' in all_op:
        angles = Input_dict['AngleForRotation'].split(',')
        all_op.remove('Rotate')
        for angle in angles:
            all_op.append('Rotate'+angle)
    print ('\nRunning Augmentation...!!!')
    i = 0
    for selection in all_op:
        print("operation : "+selection)
        i = i + 1
        OperationsList = []
        if  selection == 'RandomHorizontalFlip':
            OperationsList.append(globals()[selection](1))
        elif selection == 'HorizontalFlip':
            OperationsList.append(globals()[selection]())
        elif selection == 'RandomScale' or selection == 'Scale':
            OperationsList.append(globals()[selection](0.2, True))
        elif selection == 'RandomRotate':
            OperationsList.append(globals()[selection]())
        elif selection[:6] == 'Rotate':
        	OperationsList.append(globals()[selection[:6]](int(selection[6:])))
        elif selection == 'RandomTranslate':
            OperationsList.append(globals()[selection](0.2, False))
        elif selection == 'Translate':
            OperationsList.append(globals()[selection](0.2, 0.2, False))
        elif selection == 'RandomShear' or selection == 'Shear':
            arg = 0.2
            OperationsList.append(globals()[selection](arg))
        elif selection == 'GaussianFiltering':
            filter_size = Input_dict['FilterSizeForGaussianFiltering']
            OperationsList.append(globals()[selection](filter_size))
        elif selection == 'RandomBrightness2_0':
            gamma = Input_dict['GammaForRandomBrightness2']
            OperationsList.append(globals()['RandomBrightness'](gamma))
        elif selection == 'RandomBrightness0_5':
            gamma = Input_dict['GammaForRandomBrightness1']
            OperationsList.append(globals()['RandomBrightness'](gamma))
        elif selection == 'addsnow':
            snow_coeff = Input_dict['SnowCoeffForAddSnow']
            OperationsList.append(globals()[selection](snow_coeff))
        elif selection == 'Resize':
            resize = (Input_dict['resizeheight'], Input_dict['resizewidth'])
            print("resize -",resize)
            OperationsList.append(globals()[selection](resize))
        prefixImgLabName = ''.join(selection) + '_'

        assert not len(OperationsList) == 0, \
            'Please select valid operation from above list'+selection[:5]
        print ("\nOperation number ",i,"out of",len(all_op))
        obj.AugmentationOfImg(prefixImgLabName)

    print ('\n\nTotal augmented img count -', Total_aug_cnt)
    #print ('Total Person count - ', Person_cnt,"\n")
    print ('Done Augmentation...!!!')