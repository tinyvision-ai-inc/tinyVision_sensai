import os, sys, time, copy
import multiprocessing as mp
import tarfile, zipfile
from six.moves import urllib
import numpy as np
from librosa import resample 
from soundfile import read, write
from tqdm import tqdm

from functools import partial
print = partial(print, flush=True)

def find_all_wav_files_in_directory(filepath):
     assert os.path.isdir(filepath)
     num_wav_files = 0
     for root, folders, files in os.walk(filepath):
          if files != []:
               numfiles = len([file for file in os.listdir(root) if file.endswith(".wav")])
               num_wav_files += numfiles
     return num_wav_files


def check_progress_sr_conversion(result):
     """
     This function is used to check the status of sample rate conversion. This is a callback 
     function used by all the pool workers. So whenever a pool worker finishes the task, the callback function
     prints the progress in the number of files that have undergone sample rate conversion.
     """
     filepath, savepath = result[0], result[1]
     assert os.path.isdir(filepath)
     assert os.path.isdir(savepath)
     wav_load = find_all_wav_files_in_directory(filepath)
     wav_convert = find_all_wav_files_in_directory(savepath)
     sys.stdout.write('\r\nSample rate conversion \t Total: {}  Converted: {} ({} %)'.format(wav_load, \
          wav_convert, round(100.0*float(wav_convert/wav_load), 2)))
     sys.stdout.flush()


def convert_samplerate(filepath, savepath, new_samplerate=8000):
     """
     This function takes in a {path to a folder containing wav files} and converts
     the sample rate of all these wav files to the value given by {new_samplerate}.
     The {savedir} contains the path where the converted wav files will be saved, as per
     the keywords/categories of wav files, if any.
     """
     sr_new = new_samplerate
     check_progress_sr_conversion((filepath, savepath))
     """How many keywords/audio classes are in the raw data folder"""
     keywords = [folder for folder in os.listdir(filepath) if os.path.isdir(os.path.join(filepath, folder))]
     # zipped_args = zip(repeat(filepath), repeat(savepath), keywords, repeat(sr_new))
     try:
          """Using all the CPU cores as weorkers"""
          pool = mp.Pool(processes=mp.cpu_count())
          for keyword in keywords:
               pool.apply_async(convert_samplerate_math, (filepath, savepath, keyword, sr_new), \
                    callback=check_progress_sr_conversion)
          pool.close()
          pool.join()
     except KeyboardInterrupt:
          pool.terminate()
     


def convert_samplerate_math(filepath, savepath, keyword, sr_new):
     os.makedirs(os.path.join(savepath, keyword), exist_ok=True)
     wavlist_to_load = [file for file in os.listdir(os.path.join(filepath, keyword)) if file.endswith(".wav")]
     wavlist_to_save = [file for file in os.listdir(os.path.join(savepath, keyword)) if file.endswith(".wav")]

     """
     For each keyword/audio class, find the number of wav files. And create
     corresponding directories in the {savedir} folder for each keyword for saving
     the sample rate converted wav files.
     Note that this nested loop has "start where you stopped last time" facility.
     Hence, the wav files at the 'raw data' and the 'converted data' folder will be
     compared. And if there is any mismatch, all the wav files for this particular keyword
     will undergo sample rate conversion.
     """

     if wavlist_to_load != wavlist_to_save:
          try:
               for wavfile in wavlist_to_load:
                    audio_load_path = os.path.abspath(os.path.join(filepath, keyword, wavfile))
                    audio_save_path = os.path.abspath(os.path.join(savepath, keyword, wavfile))
                    audio_load, sr_old = read(audio_load_path)
                    audio_save = resample(audio_load, sr_old, sr_new)
                    write(audio_save_path, audio_save, sr_new)
                    del audio_load_path, audio_load, audio_save_path, audio_save
          except KeyboardInterrupt:
               raise Exception("Keyboard Interrupt pressed...")
     else:
          print('\nSkipping samplerate conversion for {}'.format(keyword.upper()))
          
     """ 
     Returning the main data folder locations to check progress using callback 
     function of the pool workers
     """
     return (filepath, savepath)   



