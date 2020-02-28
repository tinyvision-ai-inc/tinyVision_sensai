"""
Created on Thu Sep 6 15:26:30 2018

@author: ytan
""" 
import os
import sys
from enum import Enum 
import tensorflow.compat.v1 as tf 
from tensorflow.python.platform import gfile
from google.protobuf import text_format as pbtf  

from tensorflow.python.tools import optimize_for_inference_lib
from tensorflow.python.tools import freeze_graph
#from tensorflow.python.tools import import_pb_to_tensorboard as pb2TB  
import argparse
from config import *
from nets import *


def get_platform():
  platforms = {
    'linux1': 'Linux',
    'linux2': 'Linux',
    'linux' : 'Linux',
    'darwin': 'OS X',
    'win32': 'Windows'
  }
  if sys.platform not in platforms:
    return sys.platform
  return platforms[sys.platform]

def find_output_nodes(gdef, currNode):
    outNodes = []
    # print('find_output_nodes currNode ', currNode)

    for node in gdef.node:
        # if(node.op=='Sub'):
        # print('Sub node name  input',node.name,node.input)
        if node.name == currNode.name:
            continue
        if (currNode.op == 'Split'):
            for text in node.input:
                # print(currNode.name,'  output : ',node.name, node.input)
                if currNode.name in text:  # As split can be as input  as split:2,split:1, split
                    outNodes.append(node)
                    print(('Split out', node.name))
                    break

        else:
            if currNode.name in node.input:
                # print(currNode.name,'  output : ',node.name, node.input)
                outNodes.append(node)
    return outNodes
class tfPBfileMode(Enum):
     Binary=0
     Text=1
 
def setNodeAttribute(node, tag ,shapeArray):
    if(shapeArray is not None):
        if(tag=='shapes'): # here we assume  always only get first shape in shape list
             if(len(shapeArray)==4):
                  node.attr[tag].list.shape.extend([tf.TensorShape(shapeArray).as_proto()] )
             elif( len(shapeArray)==3): 
                 node.attr[tag].list.shape[0].dim[0].size =1
                 node.attr[tag].list.shape[0].dim[0].size = shapeArray[0]
                 node.attr[tag].list.shape[0].dim[1].size = shapeArray[1]
                 node.attr[tag].list.shape[0].dim[2].size = shapeArray[2]
                 
        if(tag=='shape'): #TODO  Set shape is not working  
                         
             if(len(shapeArray)==4):
                  node.attr[tag].shape.CopyFrom(tf.TensorShape(shapeArray).as_proto())    
             elif( len(shapeArray)==3): 
                 shapeArray4= [None] *4
                 
                 shapeArray4[0] = 1 
                 shapeArray4[1] = shapeArray[1]
                 shapeArray4[2] = shapeArray[2]
                 shapeArray4[3] = shapeArray[3]
                 node.attr[tag].shape.CopyFrom(tf.TensorShape(shapeArray).as_proto())     
       
             
def getInputShapeForTF(node, tag ,forceNumTobe1=True):
    shapeArray= [None] *4
    if(tag=='shapes'): #TODO here we assume and always only get first shape in shape list
         if(len(node.attr[tag].list.shape)>0):
             if(len( node.attr[tag].list.shape[0].dim)==4): 
                  
                 for i in range(len(node.attr[tag].list.shape[0].dim)):
                     shapeArray[i] = node.attr[tag].list.shape[0].dim[i].size
            
             elif( len(node.attr[tag].list.shape[0].dim)==3):
                  
                 shapeArray[0] = 1 
                 shapeArray[1] = node.attr[tag].list.shape[0].dim[0].size
                 shapeArray[2] = node.attr[tag].list.shape[0].dim[1].size
                 shapeArray[3] = node.attr[tag].list.shape[0].dim[2].size
             
    if(tag=='shape'):  
         
         if(len( node.attr[tag].shape.dim)==4): 
              
             for i in range(len(node.attr[tag].shape.dim)):
                 shapeArray[i] = node.attr[tag].shape.dim[i].size
        
         elif( len(node.attr[tag].shape.dim)==3):
              
             shapeArray[0] = 1 
             shapeArray[1] = node.attr[tag].shape.dim[0].size
             shapeArray[2] = node.attr[tag].shape.dim[1].size
             shapeArray[3] = node.attr[tag].shape.dim[2].size
    
    if(tag=='output_shapes'):  
          if(len(node.attr[tag].list.shape)>0):
             if(len( node.attr[tag].list.shape[0].dim)==4): 
                  
                 for i in range(len(node.attr[tag].list.shape[0].dim)):
                     shapeArray[i] = node.attr[tag].list.shape[0].dim[i].size
            
             elif( len(node.attr[tag].list.shape[0].dim)==3):
                  
                 shapeArray[0] = 1 
                 shapeArray[1] = node.attr[tag].list.shape[0].dim[0].size
                 shapeArray[2] = node.attr[tag].list.shape[0].dim[1].size
                 shapeArray[3] = node.attr[tag].list.shape[0].dim[2].size
    
    if(forceNumTobe1 and shapeArray[0] is not None):
        shapeArray[0]=1 
                   
    return shapeArray
             

def getShapeArrays(node): 
    inputShape= [None] *4 
    inputShape = getInputShapeForTF(node,'shape')  
    print('inputShape shape',inputShape)
    if ( inputShape[0] is None):
        inputShape = getInputShapeForTF(node,'shapes')
        print('inputShape shapes',inputShape)
    if (inputShape[0] is not None): 
        return inputShape
    else:
        inputShape = getInputShapeForTF(node,'output_shapes')
        print('output_shapes of input Node',inputShape)
        if(inputShape[0] is None) :
            msg=' **TensorFlow**: can not locate input shape information at: ' +node.name
            print(msg)
        else:
            return inputShape
       
        #raise Exception(msg) 

        
     
def createTensorboard(modelFullPath,tensorboardPath,runLocalimport_pb_to_tensorboard=True):  
      if not os.path.exists(tensorboardPath):
          os.makedirs(tensorboardPath)
      print('tensorboardPath:',tensorboardPath)
      map( os.unlink, (os.path.join( tensorboardPath,f) for f in os.listdir(tensorboardPath)) )
      pb2TB.import_to_tensorboard(modelFullPath,tensorboardPath)

def latestckpt(name):
	return int(name.split(".")[-2].split("-")[-1])
          
def parseCkptFolder(fullPathOfFolder,shapeInforNodeName,inputNodeName, outputNodeName):
    
    filename_w_ext = os.path.basename(fullPathOfFolder)
    modelName, file_extension = os.path.splitext(filename_w_ext)
    if get_platform() == 'Linux':
        folderDir=os.path.dirname(fullPathOfFolder)+'/'
    else:
        folderDir=os.path.dirname(fullPathOfFolder)+'\\'
    
    files = os.listdir(os.getcwd())
    meta_files = [s for s in files if s.endswith('.meta')]
    meta_files = sorted(meta_files, key = latestckpt)
    graph_def = tf.GraphDef() 
    ckptFile = os.path.basename(meta_files[-1])
    ckptWith1ndExtension, ckpt_metansion = os.path.splitext(ckptFile)
    ckptWith2ndExtension, ckptextension = os.path.splitext(ckptWith1ndExtension)
    
    if(file_extension=='.pbtxt'):
        with tf.gfile.FastGFile(fullPathOfFolder, 'r') as f:
            graph_str = f.read()
            pbtf.Parse(graph_str, graph_def)  
            ckptPBMode=tfPBfileMode.Text 
    else:
        with tf.gfile.FastGFile(fullPathOfFolder, 'rb') as f:
            graph_def.ParseFromString(f.read()) 
            ckptPBMode=tfPBfileMode.Binary 
    inputShapeArray=[] 
    graph_nodes=[n for n in graph_def.node]
    for node in graph_nodes: 
        if shapeInforNodeName == node.name: 
           inputShapeArray=getShapeArrays(node)  
    return [ckptextension,ckptPBMode, folderDir,inputShapeArray] 
           
  

def settingsConf(modelInfors ): 
    checkpointExt=modelInfors[0]   
    pbFileType=modelInfors[1]
    checkpointPath= modelInfors[2] 
    folderPath=checkpointPath
    shapeArray= modelInfors[3] 
    
    if(pbFileType==tfPBfileMode.Binary):
        msuffix='.pb'   
        readMode='rb'
        binaryPB=True
    elif(pbFileType==tfPBfileMode.Text):
        binaryPB=False
        msuffix='.pbtxt' 
        readMode='r'  
    
    return msuffix,binaryPB,readMode,folderPath,checkpointExt,checkpointPath,shapeArray

def loadGraph(filePath,binaryPB):
    graph_def = tf.GraphDef()
    if(binaryPB):
        with gfile.FastGFile(filePath,'rb') as f:
            graph_def.ParseFromString(f.read())
             
    else:
        with gfile.FastGFile(filePath,'r') as f:
            graph_str = f.read()
            pbtf.Parse(graph_str, graph_def)   
           
            
     # Then, we import the graph_def into a new Graph and returns it 
    with tf.Graph().as_default() as graph:
        # The name var will prefix every op/nodes in your graph
        # Since we load everything in a new graph, this is not needed
        tf.import_graph_def(graph_def, name="")         
    return graph,graph_def




   
def convert(file_path,inputNodeName, outputNodeName,msuffix,binaryPB,readMode,folderPath,checkpointExt,checkpointPath,modelName,shapeArray,modifyshapeAttribue ,fixBatchNormal=True) :
    tf.reset_default_graph()
    config = tf.ConfigProto(
            allow_soft_placement = True,
            device_count={"GPU": 0, "CPU": 1}
            
    )
    runIncommdLine=False
    
    g_in,graph_def =  loadGraph(file_path,binaryPB)  
    
    # fix batch normal node nodes  https://github.com/tensorflow/tensorflow/issues/3628
    if(fixBatchNormal): 
         
        for node in graph_def.node:
          if node.op == 'RefSwitch':
            node.op = 'Switch'
            for index in  range(len(node.input)):
              if 'moving_' in node.input[index]:
                node.input[index] = node.input[index] + '/read'
          elif node.op == 'AssignSub':
            node.op = 'Sub'
            if 'use_locking' in node.attr: del node.attr['use_locking']
          elif node.op == 'AssignAdd':
            node.op = 'Add'
            if 'use_locking' in node.attr: del node.attr['use_locking']
          if('dilations')    in node.attr: del node.attr['dilations']  
          node.device=""
          
          
        #fixVariables not Working  
        fixVariables  =False 
        if (fixVariables and node.op == 'VariableV2' and ('batchnorm/var' in node.name or 'batchnorm/mean' in node.name)):
              outputNodes=find_output_nodes(graph_def,node) 
              for index in  range(len( outputNodes )):
                  if(outputNodes[index].op=='Assign'   ):
                        #node.output[index] = node.output[index] + '/read'
                        #outputNodes[index].op ='Identity'
                        outputNodes[index].name = outputNodes[index].name+ '/read'
                        print('Modified %s '%outputNodes[index].name) 
                       
                 
                
                
   
                    
#################### Step 1 Training to inference simplification  , need checkpoint and  .pbtxt files from training   ######################################################      
               
                
    graphDef = optimize_for_inference_lib.optimize_for_inference(
                        graph_def,
                        [inputNodeName], # an array of the input node(s)
                        [outputNodeName] if type(outputNodeName)  is str  else [item for item in outputNodeName  ], # an array of output nodes
                        tf.float32.as_datatype_enum)
    
     
    if(modifyshapeAttribue):
        
        for n in  graphDef.node: 
            if((n.op=='Placeholder' or n.op=='Reshape') and n.name==inputNodeName):
                print('node to modify',n)
                setNodeAttribute(n,'shape',shapeArray)
                print("--Name of the node - %s shape set to " %  n.name,inputNodeName,shapeArray)
                print('node after modify',n)
    #graphDef=remove_training_nodes(output_graph_def)
    #graphDef = convert_variables_to_constants(sess, graphDef, [outputNodeName]) 
    
    if(runIncommdLine):
        copyfile(file_path,file_path+trainModelSuffix)  
    outputNameSuffix=  '_frozenforInference.pb'
    inferenceSuffix='.Inference'
    tf.train.write_graph(graphDef,folderPath, checkpointPath+modelName+'.pb'+inferenceSuffix, as_text=False)  
    tf.train.write_graph(graphDef,folderPath, checkpointPath+modelName+'.pbtxt'+inferenceSuffix, as_text=True)
        
    
    
    
    pbfileoutput_path=checkpointPath+modelName+outputNameSuffix
    checkpointfile_path=checkpointPath+modelName+checkpointExt
          
    pbfile_path=checkpointPath+modelName+msuffix+inferenceSuffix 
####################   Step 2                    Frozen Inference mode                      ######################################################                     
    
    freeze_graph.freeze_graph(
                        input_graph=pbfile_path, 
                        input_saver='',
                        input_binary=binaryPB,
                        input_checkpoint=checkpointfile_path, # an array of the input node(s)
                        output_node_names=  outputNodeName  if type(outputNodeName)  is str  else  ",".join( outputNodeName),
                        restore_op_name="save/restore_all", #Unused.
                        filename_tensor_name="save/Const:0",# Unused.
                        output_graph=pbfileoutput_path, # an array of output nodes  
                        clear_devices=True,
                        initializer_nodes=''
                        )
####################   Step 3                    Save in tensor board                     ######################################################                                         
    modelFullPath=checkpointPath+modelName+outputNameSuffix                   
    #tensorboardPath=checkpointPath+ '\\tensorboard'
    #if not os.path.exists(tensorboardPath):
      #os.mkdir(tensorboardPath)
    #createTensorboard(modelFullPath,tensorboardPath) 


def demoCKPT2PB(dataPara):  
    modelFileName=dataPara[0]    
    inputNodeName=dataPara[1]  
    shapeInforNodeName =dataPara[2]
    outputNodeName= dataPara[3] 
    modifyInputShape= dataPara[4] 
    currentFolder= os.path.dirname(os.path.realpath(__file__)) 
    currentFolder= './'
    file_path=currentFolder+modelFileName
    modelName=modelFileName.replace('.pbtxt','')
    msuffix,binaryPB,readMode,folderPath,checkpointExt,checkpointPath,shapeArray=settingsConf(parseCkptFolder(file_path,shapeInforNodeName,inputNodeName,outputNodeName)  )
    if(shapeArray is None or len(shapeArray)<1):     
        shapeArray=dataPara[5]
    
    convert(file_path,inputNodeName, outputNodeName,msuffix,binaryPB,readMode,'',checkpointExt,checkpointPath,modelName,shapeArray,modifyInputShape)              


"""
####################                Steps to process a new  tensorflow checkpoints folder                    ###################################################### 
After install dependence (tensorflow and google.protobuf)   in python environment:  

1 copy or generate .pbtxt file into the checkpoint folder
  
  python trainckpt2inferencepb.py   
  alternatively you can use Spyder, PyCharm or other python IDE to run this script


Refer to Readme.txt for more details.  

please Modify following dataPara line to process new checkpoint folder""" 

def main(args):
    indexOfModel=0
    dataParas=[['./model.pbtxt', 'image_input', 'image_input', 'conv12/convolution', \
                True,[1,args.image_width, args.image_height,1]]]
    demoCKPT2PB(dataParas[indexOfModel])

def genpb(args):
    mc = kitti_squeezeDet_config()
    mc.CLASS_NAMES = args.classes
    mc.CLASSES = len(mc.CLASS_NAMES)
    mc.IMAGE_WIDTH = args.image_width
    mc.IMAGE_HEIGHT = args.image_height

    model = SqueezeDet(mc)
    saver = tf.train.Saver(model.model_params)
    with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:
        ckpt = tf.train.latest_checkpoint("./")
        print("Using checkpoint: " + ckpt)
        saver.restore(sess, ckpt)
        tf.train.write_graph(sess.graph_def, "./", 'model.pbtxt', as_text=True)
        print("saved pbtxt at checkpoint direcory Path")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    os.environ['CUDA_VISIBLE_DEVICES'] = '-1'
    parser.add_argument("--ckpt_dir", type=str, required=True, default="", help="Checkpoint directory")
    parser.add_argument("--freeze", type=bool, required=False, default=False, help="Freeze graph for inference.")
    parser.add_argument("--classes", type=str, required=True, default=None, nargs="+", help="Names of the object classes")
    parser.add_argument("--image_width", type=int, required=False, default=64, help="Width of the input image")
    parser.add_argument("--image_height", type=int, required=False, default=64, help="Height of the input image")
    args = parser.parse_args()
    args.classes = [clsname.replace("_"," ") for clsname in args.classes]
    os.chdir(os.path.abspath(args.ckpt_dir))
    print("genrating pbtxt")
    genpb(args)
    if args.freeze:
        main(args)  

