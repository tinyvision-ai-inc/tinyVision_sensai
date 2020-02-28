import os, sys, argparse
import convert_sample_rate as csr
import tarfile
from six.moves import urllib

from functools import partial
print = partial(print, flush=True)

"""Function to download raw audio data (aka speech commands) from Google"""
def download_rawdata(data_url, dest_directory):
     if not data_url or not dest_directory:
          return
     if not os.path.exists(dest_directory):
          os.makedirs(dest_directory)

     """
     Right now, we have only 2 sources for downloading raw speech data from Google.
     If you have a different source, make sure you make suitable changes in the config file.

     {filename} is the name of the tarfile that is downloaded from Google. {rawdata_unzip} denotes
     the folder location that will contain the unzipped contents of the tarfile.
     """
     filename = data_url.split("/")[-1]
     if filename.__contains__("0.01"):
          rawdata_unzip = "speech_commands_set_1"
     elif filename.__contains__("0.02"):
          rawdata_unzip = "speech_commands_set_2"

     """Path where the tar file will be unzipped"""
     rawdata_unzip = os.path.abspath(os.path.join(dest_directory, rawdata_unzip))
     os.makedirs(rawdata_unzip, exist_ok=True)

     """Path where the tar file will be saved after download"""
     tarpath = os.path.abspath(os.path.join(dest_directory, filename))
     
     if not os.path.exists(tarpath) or os.path.getsize(tarpath) == 0:
          """
          Define a function that prints the progress during raw data download.
          """
          def download_progress(count, block_size, total_size):
               sys.stdout.write('\r>>Downloading %s %.1f%%' % \
                              (filename, 100*float(count*block_size)/float(total_size)))
               sys.stdout.flush()

          """Download the raw data from the url provided"""
          try:
               tarpath, _ = urllib.request.urlretrieve(data_url, tarpath, download_progress)
               tarpath = os.path.abspath(tarpath)
          except:
               raise Exception('Failed to download URL: %s to folder: %s', data_url, tarpath)

          statinfo = os.stat(tarpath)
          sys.stdout.write("\nSuccessfully downloaded {} ({} bytes)".format(filename, statinfo.st_size))
     else:
          sys.stdout.write("\nData already downloaded and \ncan be found at {}".format(tarpath))
     return os.path.abspath(tarpath), os.path.abspath(rawdata_unzip)


def unzip_tarfile(filepath, savepath):
     """Open the tarfile for reading"""
     sys.stdout.write("\r\nLoading tar file...This may take a while")
     tar = tarfile.open(filepath, 'r:gz')
     tarmembers = tar.getmembers()
     """Names of all the wav files in the tar ball"""
     wavfiles = [f for f in tar.getnames() if f.endswith(".wav")]
     """categories of keywords in the tar ball"""
     folders = list(set([f.split("/")[1] for f in wavfiles]))

     """
     Going through folder by folder in the tar ball. Get the list of wav files that are in the tar ball for each category
     and then check if all these wav files are also present at the destination directory. If not, then extract the wav files 
     for the keywords.
     """
     for folder in folders:
          wav_tar_names = [file.split("/")[-1] for file in wavfiles if file.__contains__("/" + folder + "/")]
          dest_directory = os.path.abspath(os.path.join(savepath, folder))
          if os.path.exists(dest_directory):
               wav_unzipped_names = [file for file in os.listdir(dest_directory) if file.endswith(".wav")]
               if len(wav_tar_names) != len(wav_unzipped_names) or wav_unzipped_names == []:
                    sys.stdout.write("\r\nFew or all of the wav files of the keyword {} have not been extracted".format(folder.upper()))
                    """Comparing lists of wav files and figuring which files have to be extracted"""
                    wav_members = [tarinfo for tarinfo in tarmembers if tarinfo.name.startswith("./" + folder)]
                    tar.extractall(path=savepath, members=wav_members)
                    del wav_members
               else:
                    sys.stdout.write("\r\nWav files for keyword {}: Found at the destination directory".format(folder.upper()))
          else:
               sys.stdout.write("\r\nKeyword {} not found at the destination directory".format(folder.upper()))
               sys.stdout.write("\r\nExtracting all wav files for the keyword {}".format(folder.upper()))
               os.makedirs(dest_directory, exist_ok=True)
               wav_members = [tarinfo for tarinfo in tarmembers if tarinfo.name.startswith("./" + folder)]
               tar.extractall(path=savepath, members=wav_members)
               del wav_members


def main():
     ##################################### MAIN CODE #####################################
     """
     {maindir} represents the main directory in which we have all the Python
     source codes, datasets and the training logs. {datadir} contains the data (including
     raw data)which will be used for training or other tasks.
     """
     maindir = os.path.dirname(__file__)
     datadir = os.path.join(maindir, "data")
     os.makedirs(datadir, exist_ok=True)
     """
     Right now, this data download utility can be used to download
     raw wav files for different keywords from 2 open-source Google datasets.
     In the near future, other data sources will be added.
     """
     parser = argparse.ArgumentParser(description="Utility to download keyword data from Google")
     parser.add_argument("--dataset", type=int, required=True, default=2, \
          help='Which dataset should we download, 1 or 2?')
     args = parser.parse_args()

     dataset = args.dataset
     if dataset == 1:
          """URL for Set 1"""
          data_url = "http://download.tensorflow.org/data/speech_commands_v0.01.tar.gz"
          print("\nDataset {} selected...Initiating raw data download from the".format(dataset))
          print("URL: {}".format(data_url))
     elif dataset == 2:
          """URL for Set 2"""
          data_url = "http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz"
          print("\nDataset {} selected...Initiating raw data download from the".format(dataset))
          print("URL: {}".format(data_url))
     else:
          print("Unknown dataset number...using default option of dataset 2")
          data_url = "http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz"
          print("\nDataset {} selected...Initiating raw data download from the".format(dataset))
          print("URL: {}\n\n".format(data_url))

     """
     Calling the data download function for one of the two above-mentioned data urls
     """
     tarpath, raw_data_path = download_rawdata(data_url, datadir)
     raw_data_folder = os.path.basename(raw_data_path)
     print("\nRaw data will be unzipped to: ")
     print(raw_data_path, "\n")

     """
     Unzip the downloaded tar file.
     Pass the path of the downloaded tar file and the intended path for the unzipped 
     data to the function {unzip_tarfile}. Note that this function has a "pick up 
     where you left" facility. 
     """
     if os.listdir(raw_data_path) == []:
          print("\nTar file has never been extracted....unzipping it now")
          tarfile.open(tarpath, 'r:gz').extractall(raw_data_path)
     else:
          print("\nTar ball seems to have been unzipped before.\nchecking for partial unzipping issues")
          unzip_tarfile(tarpath, raw_data_path)


     """
     If data avialable, start the sample rate conversion process. The data
     will be saved inside a new folder within the "data" folder created above.
     The new folder will have a suffix "_SR_{new samplerate}" to indicate the converted
     sample rate of the audio files. In this work, a sample rate of 8000 will be used.
     The user will have the freedom to choose a new sample rate and save the converted files
     to a new directory, which may be named accorrding to the chosen sample rate.
     """
     print("\n\nInitiating sample conversion process...")
     new_samplerate = 8000
     convert_sr_datasave = os.path.abspath(os.path.join(datadir, raw_data_folder + "_SR_" + str(new_samplerate)))
     os.makedirs(convert_sr_datasave, exist_ok=True)
     csr.convert_samplerate(raw_data_path, convert_sr_datasave, new_samplerate=new_samplerate)


if __name__ == "__main__":
     main()
