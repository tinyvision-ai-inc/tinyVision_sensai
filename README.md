![tinyVision.ai Inc.](./resources/images/TVAI-FINAL-01-tight.png)

# Simplifying the Lattice [SensAI](https://www.latticesemi.com/sensAI)  Framework

This repo contains a modified version of the Lattice [SensAI](https://www.latticesemi.com/sensAI)  framework. This can be used to train a neural network and target the Lattice AI core that runs on an FPGA.

* Training: This directory contains various training examples for Audio and vision modalities. Various examples such as keyword detection, human face detection and so on are covered. The output of this training is a binary file that can be written into the Flash that the FPGA can load from.
* RTL: This directory follows the Lattice examples quite faithfully and contains modified example code that will allow one to use the training model output from the above directory. Note that we support two different targets:
  * [UPduino Himax adapter](http://www.latticesemi.com/himax): This board set comes with an UPduino and a Himax adapter(hat) and supports two microphones and a low power, color qVGA (320x24) rolling shutter Himax image sensor.
  * Vision FPGA SoM: This board is more production oriented and in addition to the Himax sensor, can also support an even lower power, monochrome, qVGA (320x240), global shutter image sensor made by [Pixart Imaging](www.pixart.com).