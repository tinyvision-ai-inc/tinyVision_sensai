using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using Microsoft.Win32;
using System.IO;
using System.IO.Ports;
using System.Threading;
using System.Windows.Threading;
using System.Windows.Forms;
using System.Collections.ObjectModel;
using System.Management;

namespace uart_display
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public uint[] FrameBuffer;
        byte[] sp_buffer;
        private WriteableBitmap smallBitmap;
        private WriteableBitmap mediumBitmap;
        private WriteableBitmap largeBitmap;

        private ManagementEventWatcher watcher_add;
        private ManagementEventWatcher watcher_remove;

        SerialPort sp;

        bool en_sp_get = false;
        bool en_result = false;

        string start_char = "h";

        Dictionary<string, int> com_port_list;

        private int file_idx;

        public MainWindow()
        {
            InitializeComponent();

            watcher_add = new ManagementEventWatcher();

            WqlEventQuery query_add = new WqlEventQuery("SELECT * FROM Win32_DeviceChangeEvent WHERE EventType = 2");
            watcher_add.EventArrived += new EventArrivedEventHandler(watcher_Event_add);
            watcher_add.Query = query_add;
            watcher_add.Start();

            watcher_remove = new ManagementEventWatcher();

            WqlEventQuery query_remove = new WqlEventQuery("SELECT * FROM Win32_DeviceChangeEvent WHERE EventType = 3");
            watcher_remove.EventArrived += new EventArrivedEventHandler(watcher_Event_remove);
            watcher_remove.Query = query_remove;
            watcher_remove.Start();

            sp = new SerialPort();

            com_port_list = new Dictionary<string, int>();

            int port_num = 0;

            foreach (string s in System.IO.Ports.SerialPort.GetPortNames())
            {
                comboBoxUartPorts.Items.Add(s);
                com_port_list.Add(s, port_num++);
            }
            if(port_num > 0)
                comboBoxUartPorts.SelectedIndex = 0;

            FrameBuffer = new uint[32760];
            sp_buffer = new byte[65536];

            smallBitmap = new WriteableBitmap(32, 32, 96, 96, PixelFormats.Bgra32, null);   
            //smallBitmap = BitmapFactory.New(32, 32);

            imageSmall.Source = smallBitmap;

            mediumBitmap = new WriteableBitmap(64, 64, 96, 96, PixelFormats.Bgra32, null);

            imageMedium.Source = mediumBitmap;

            largeBitmap = new WriteableBitmap(170, 128, 96, 96, PixelFormats.Bgra32, null);

            imageLarge.Source = largeBitmap;

            textBoxFolder.Text = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
        }

        public void watcher_Event_add(object sender, EventArrivedEventArgs e)
        {

            this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
            {
                foreach (string s in System.IO.Ports.SerialPort.GetPortNames())
                {
                    // Check whether new one exist or not
                    if (com_port_list.ContainsKey(s) == false)
                    {
                        comboBoxUartPorts.Items.Add(s);
                        comboBoxUartPorts.SelectedIndex = comboBoxUartPorts.Items.Count - 1;
                        com_port_list.Add(s, comboBoxUartPorts.SelectedIndex);
                    }
                }
            }));

        }

        public void watcher_Event_remove(object sender, EventArrivedEventArgs e)
        {
            this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
            {
                // save current list and selected item
                string selected_port;
                if (comboBoxUartPorts.SelectedIndex >= 0)
                    selected_port = comboBoxUartPorts.Items[comboBoxUartPorts.SelectedIndex].ToString();
                else
                    selected_port = "";

                // Clear all dictionary and combobox
                comboBoxUartPorts.SelectedIndex = -1;
                com_port_list.Clear();
                comboBoxUartPorts.Items.Clear();

                int port_num = 0;
                foreach (string s in System.IO.Ports.SerialPort.GetPortNames())
                {
                    comboBoxUartPorts.Items.Add(s);
                    com_port_list.Add(s, port_num++);
                }

                // check whether previously selected port is still avaialble or not
                if (com_port_list.ContainsKey(selected_port) == true)
                {
                    comboBoxUartPorts.SelectedIndex = com_port_list[selected_port];
                }
                else
                {
                    // select first one
                    if (port_num > 0)
                        comboBoxUartPorts.SelectedIndex = 0;
                }
            }));

        }

        private void buttonSave_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // get the file name to save the list view information in from the standard save dialog
                var saveFileDialog = new Microsoft.Win32.SaveFileDialog { CheckFileExists = false, Filter = "PNG file(*.png)|*.png|All files(*)|*", AddExtension = false };
                var result = saveFileDialog.ShowDialog();
                int actualHeight;
                int actualWidth;

                int p, r, g, b;

                //saveFileDialog.FileName = saveFileDialog.FileName + ".png";

                if (result == true)
                {
                    // Delete the file if it exists
                    if (File.Exists(saveFileDialog.FileName))
                    {
                        File.Delete(saveFileDialog.FileName);
                    }

                    System.Drawing.Bitmap save_bitmap;


                    actualHeight = 64;
                    actualWidth = 64;

                    save_bitmap = new System.Drawing.Bitmap(actualWidth, actualHeight);

                    for (int y = 0; y < actualHeight; y++)
                    {
                        for (int x = 0; x < actualWidth; x++)
                        {

                            p = (int)FrameBuffer[y * 64 + x];
                            r = (p >> 16) & 0xff;
                            g = (p >> 8) & 0xff;
                            b = (p) & 0xff;

                            save_bitmap.SetPixel(x, y, System.Drawing.Color.FromArgb(r, g, b));

                        }
                    }
                    save_bitmap.Save(saveFileDialog.FileName);


                }
            }
            catch
            {

            }

        }

        private void buttonSave32_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // get the file name to save the list view information in from the standard save dialog
                var saveFileDialog = new Microsoft.Win32.SaveFileDialog { CheckFileExists = false, Filter = "PNG file(*.png)|*.png|All files(*)|*", AddExtension = false };
                var result = saveFileDialog.ShowDialog();
                int actualHeight;
                int actualWidth;

                int p, r, g, b;

                //saveFileDialog.FileName = saveFileDialog.FileName + ".png";

                if (result == true)
                {
                    // Delete the file if it exists
                    if (File.Exists(saveFileDialog.FileName))
                    {
                        File.Delete(saveFileDialog.FileName);
                    }

                    System.Drawing.Bitmap save_bitmap;


                    actualHeight = 32;
                    actualWidth = 32;

                    save_bitmap = new System.Drawing.Bitmap(actualWidth, actualHeight);

                    for (int y = 0; y < actualHeight; y++)
                    {
                        for (int x = 0; x < actualWidth; x++)
                        {

                            p = (int)FrameBuffer[y * 32 + x];
                            r = (p >> 16) & 0xff;
                            g = (p >> 8) & 0xff;
                            b = (p) & 0xff;

                            save_bitmap.SetPixel(x, y, System.Drawing.Color.FromArgb(r, g, b));

                        }
                    }
                    save_bitmap.Save(saveFileDialog.FileName);


                }
            }
            catch
            {

            }

        }

        Thread UartUpdateThread;

        private void sp_update()
        {
            int rd_size;
            int rd_total_size;
            byte r, g, b;

            int total_size;

            short result;

            total_size = 12288;

            if(en_result)
                total_size += 2;

            while (en_sp_get)
            {
                sp.Write(start_char);

                rd_total_size = 0;
                try
                {
                    do
                    {
                        rd_size = sp.Read(sp_buffer, rd_total_size, 255);

                        rd_total_size += rd_size;

                    } while (rd_total_size < total_size);
                }
                catch (Exception ex)
                {
                    sp.Close();
                    this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                    {
                        en_sp_get = false;

                        buttonUartGet.Content = "Uart get";
                        buttonUartGet32.IsEnabled = true;
                        buttonUartGetGray.IsEnabled = true;
                    }));
                }

                for (int y = 0; y < 64; y++)
                {
                    for (int x = 0; x < 64; x++)
                    {
                        if (total_size >= 12288) // 888
                        {
                            /* frame read from video processor
                            r = sp_buffer[y * 192 + x * 3 + 2];
                            g = sp_buffer[y * 192 + x * 3 + 1];
                            b = sp_buffer[y * 192 + x * 3 + 0];
                             * */
                            r = (byte)(sp_buffer[y * 64 + x + 8192] + 128);
                            g = (byte)(sp_buffer[y * 64 + x + 4096] + 128);
                            b = (byte)(sp_buffer[y * 64 + x + 0] + 128);

                        }
                        else // 565
                        {
                            r = (byte)(sp_buffer[y * 128 + x * 2 + 1] & 0xf8);
                            g = (byte)(((sp_buffer[y * 128 + x * 2 + 1] & 0x07) << 5) + ((sp_buffer[y * 128 + x * 2 + 0] & 0xe0) >> 3));
                            b = (byte)((sp_buffer[y * 128 + x * 2 + 0] & 0x1f) << 3);

                        }
                        FrameBuffer[y * 64 + x] = (uint)(0xff000000 + (r << 16) + (g << 8) + b);
                    }
                }

                if (en_result)
                {
                    result = (short)((sp_buffer[12289] << 8) | (sp_buffer[12288]));
                }
                else
                {
                    result = 0;
                }

                this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                {
                    mediumBitmap.WritePixels(new Int32Rect(0, 0, 64, 64), FrameBuffer, 64 * 4, 0);
                    textBoxResultMedium.Text = result.ToString();

                    if (checkBoxSaveImages.IsChecked == true)
                    {
                        saveImage(textBoxFolder.Text + "\\" + textBoxPrefix.Text + file_idx.ToString() + ".png", 64);
                        file_idx++;
                    }
                }));
            }

            sp.Close();
        }

        private void sp_update32()
        {
            int rd_size;
            int rd_total_size;
            byte r, g, b;

            int total_size;

            total_size = 3072;

            while (en_sp_get)
            {
                sp.Write(start_char);

                rd_total_size = 0;
                try
                {
                    do
                    {
                        rd_size = sp.Read(sp_buffer, rd_total_size, 255);

                        rd_total_size += rd_size;

                    } while (rd_total_size < total_size);
                }
                catch (Exception ex)
                {
                    sp.Close();
                    this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                    {
                        en_sp_get = false;

                        buttonUartGet32.Content = "Uart get 32";
                        buttonUartGet.IsEnabled = true;
                        buttonUartGetGray.IsEnabled = true;
                    }));
                }

                for (int y = 0; y < 32; y++)
                {
                    for (int x = 0; x < 32; x++)
                    {
                        if (total_size == 3072) // 888
                        {
                            // from video proessor 
                            r = (byte)(sp_buffer[y * 96 + x * 3 + 2] + 128);
                            g = (byte)(sp_buffer[y * 96 + x * 3 + 1] + 128);
                            b = (byte)(sp_buffer[y * 96 + x * 3 + 0] + 128);

                            /* from ML engine
                            r = (byte)(sp_buffer[y * 32 + x + 2048] + 128);
                            g = (byte)(sp_buffer[y * 32 + x + 1024] + 128);
                            b = (byte)(sp_buffer[y * 32 + x + 0] + 128);
                            */
                        }
                        else // 565
                        {
                            r = (byte)(sp_buffer[y * 64 + x * 2 + 1] & 0xf8);
                            g = (byte)(((sp_buffer[y * 64 + x * 2 + 1] & 0x07) << 5) + ((sp_buffer[y * 128 + x * 2 + 0] & 0xe0) >> 3));
                            b = (byte)((sp_buffer[y * 64 + x * 2 + 0] & 0x1f) << 3);

                        }
                        FrameBuffer[y * 32 + x] = (uint)(0xff000000 + (r << 16) + (g << 8) + b);
                    }
                }

                this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                {
                    smallBitmap.WritePixels(new Int32Rect(0, 0, 32, 32), FrameBuffer, 32 * 4, 0);

                    if (checkBoxSaveImages.IsChecked == true)
                    {
                        saveImage(textBoxFolder.Text + "\\" + textBoxPrefix.Text + file_idx.ToString() + ".png");
                        file_idx++;
                    }
                }));
            }

            sp.Close();
        }

        private void sp_update32Gray()
        {
            int rd_size;
            int rd_total_size;
            byte r, g, b;

            int total_size;

            total_size = 1024;

            while (en_sp_get)
            {
                sp.Write(start_char);

                rd_total_size = 0;
                try
                {
                    do
                    {
                        rd_size = sp.Read(sp_buffer, rd_total_size, 255);

                        rd_total_size += rd_size;

                    } while (rd_total_size < total_size);
                }
                catch (Exception ex)
                {
                    sp.Close();
                    this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                    {
                        en_sp_get = false;

                        buttonUartGetGray.Content = "Uart get gray";
                        buttonUartGet.IsEnabled = true;
                        buttonUartGet32.IsEnabled = true;
                    }));
                }

                for (int y = 0; y < 32; y++)
                {
                    for (int x = 0; x < 32; x++)
                    {
                        r = g = b = (byte)(sp_buffer[y * 32 + x] + 128);
                        FrameBuffer[y * 32 + x] = (uint)(0xff000000 + (r << 16) + (g << 8) + b);
                    }
                }

                this.Dispatcher.Invoke(DispatcherPriority.Normal, new Action(() =>
                {
                    smallBitmap.WritePixels(new Int32Rect(0, 0, 32, 32), FrameBuffer, 32 * 4, 0);

                    if (checkBoxSaveImages.IsChecked == true)
                    {
                        saveImage(textBoxFolder.Text + "\\" + textBoxPrefix.Text + file_idx.ToString() + ".png");
                        file_idx++;
                    }

                }));
            }

            sp.Close();
        }

        private void buttonUartGet_Click(object sender, RoutedEventArgs e)
        {
            en_result = (checkBoxEnResultMedium.IsChecked == true);
            file_idx = 1;

            if (en_sp_get == false)
            {
                sp.PortName = comboBoxUartPorts.Items[comboBoxUartPorts.SelectedIndex].ToString();
                sp.BaudRate = 230400;
                sp.Parity = Parity.None;
                sp.DataBits = 8;
                sp.StopBits = StopBits.One;

                sp.ReadTimeout = 3000;
                sp.Open();

                en_sp_get = true;

                buttonUartGet.Content = "Stop Uart";
                buttonUartGet32.IsEnabled = false;
                buttonUartGetGray.IsEnabled = false;

                UartUpdateThread = new Thread(new ThreadStart(sp_update));
                UartUpdateThread.Start();
            }
            else
            {
                en_sp_get = false;

                buttonUartGet.Content = "Uart get";
                buttonUartGet32.IsEnabled = true;
                buttonUartGetGray.IsEnabled = true;

            }
        }

        private void buttonUartGet32_Click(object sender, RoutedEventArgs e)
        {
            file_idx = 1;

            if (en_sp_get == false)
            {
                sp.PortName = comboBoxUartPorts.Items[comboBoxUartPorts.SelectedIndex].ToString();
                sp.BaudRate = 230400;
                sp.Parity = Parity.None;
                sp.DataBits = 8;
                sp.StopBits = StopBits.One;

                sp.ReadTimeout = 2000;
                sp.Open();

                en_sp_get = true;

                buttonUartGet32.Content = "Stop Uart 32";
                buttonUartGet.IsEnabled = false;
                buttonUartGetGray.IsEnabled = false;

                UartUpdateThread = new Thread(new ThreadStart(sp_update32));
                UartUpdateThread.Start();
            }
            else
            {
                en_sp_get = false;

                buttonUartGet32.Content = "Uart get 32";
                buttonUartGet.IsEnabled = true;
                buttonUartGetGray.IsEnabled = true;
            }
        }

        private void buttonUartGetGray_Click(object sender, RoutedEventArgs e)
        {
            file_idx = 1;

            if (en_sp_get == false)
            {
                sp.PortName = comboBoxUartPorts.Items[comboBoxUartPorts.SelectedIndex].ToString();
                sp.BaudRate = 230400;
                sp.Parity = Parity.None;
                sp.DataBits = 8;
                sp.StopBits = StopBits.One;

                sp.ReadTimeout = 2000;
                sp.Open();

                en_sp_get = true;

                buttonUartGetGray.Content = "Stop Uart";
                buttonUartGet.IsEnabled = false;
                buttonUartGet32.IsEnabled = false;

                UartUpdateThread = new Thread(new ThreadStart(sp_update32Gray));
                UartUpdateThread.Start();
            }
            else
            {
                en_sp_get = false;

                buttonUartGetGray.Content = "Uart get gray";
                buttonUartGet.IsEnabled = true;
                buttonUartGet32.IsEnabled = true;

            }
        }

        private void comboBoxSel_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            switch (comboBoxSel.SelectedIndex)
            {
                case 0: start_char = "h";
                    break;
                case 1: start_char = "i";
                    break;
                case 2: start_char = "j";
                    break;
                case 3: start_char = "k";
                    break;
                case 4: start_char = "l";
                    break;
                default: start_char = "m";
                    break;

            }

        }

        private void saveImage(string FileName, int size = 32)
        {
            System.Drawing.Bitmap save_bitmap;

            int p, r, g, b;

            save_bitmap = new System.Drawing.Bitmap(size, size);

            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {

                    p = (int)FrameBuffer[y * size + x];
                    r = (p >> 16) & 0xff;
                    g = (p >> 8) & 0xff;
                    b = (p) & 0xff;

                    save_bitmap.SetPixel(x, y, System.Drawing.Color.FromArgb(r, g, b));

                }
            }
            save_bitmap.Save(FileName);
        }

        private void buttonSelectFolder_Click(object sender, RoutedEventArgs e)
        {
            var folderBrowseDialog = new FolderBrowserDialog();
            folderBrowseDialog.SelectedPath = textBoxFolder.Text;

            var result = folderBrowseDialog.ShowDialog();

            if (result == System.Windows.Forms.DialogResult.OK)
            {
                textBoxFolder.Text = folderBrowseDialog.SelectedPath;

            }
        }

        private void buttonGetRaw_Click(object sender, RoutedEventArgs e)
        {
            file_idx = 1;

            sp.PortName = comboBoxUartPorts.Items[comboBoxUartPorts.SelectedIndex].ToString();
            sp.BaudRate = 230400;
            sp.Parity = Parity.None;
            sp.DataBits = 8;
            sp.StopBits = StopBits.One;

            sp.ReadTimeout = 2000;
            sp.Open();

            int rd_size;
            int rd_total_size;
            byte r, g, b;

            byte[] start_char = new byte[2];

            start_char[0] = (byte)85;

            int total_size;

            total_size = 43520;

            sp.Write(start_char, 0, 1);

            rd_total_size = 0;
            try
            {
                do
                {
                    rd_size = sp.Read(sp_buffer, rd_total_size, 255);

                    rd_total_size += rd_size;

                } while (rd_total_size < total_size);
            }
            catch (Exception ex)
            {
            }

            sp.Close();

            for (int y = 0; y < 128; y++)
            {
                for (int x = 0; x < 170; x++)
                {
                    r = (byte)(sp_buffer[y * 340 + x * 2 + 0] & 0xf8);
                    g = (byte)(((sp_buffer[y * 340 + x * 2 + 0] & 0x07) << 5) + ((sp_buffer[y * 340 + x * 2 + 1] & 0xe0) >> 3));
                    b = (byte)((sp_buffer[y * 340 + x * 2 + 1] & 0x1f) << 3);

                    FrameBuffer[y * 170 + x] = (uint)(0xff000000 + (r << 16) + (g << 8) + b);
                }
            }
            largeBitmap.WritePixels(new Int32Rect(0, 0, 170, 128), FrameBuffer, 170 * 4, 0);

        }

        private void buttonSaveLarge_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // get the file name to save the list view information in from the standard save dialog
                var saveFileDialog = new Microsoft.Win32.SaveFileDialog { CheckFileExists = false, Filter = "PNG file(*.png)|*.png|All files(*)|*", AddExtension = false };
                var result = saveFileDialog.ShowDialog();
                int actualHeight;
                int actualWidth;

                int p, r, g, b;

                //saveFileDialog.FileName = saveFileDialog.FileName + ".png";

                if (result == true)
                {
                    // Delete the file if it exists
                    if (File.Exists(saveFileDialog.FileName))
                    {
                        File.Delete(saveFileDialog.FileName);
                    }

                    System.Drawing.Bitmap save_bitmap;


                    actualHeight = 128;
                    actualWidth = 170;

                    save_bitmap = new System.Drawing.Bitmap(actualWidth, actualHeight);

                    for (int y = 0; y < actualHeight; y++)
                    {
                        for (int x = 0; x < actualWidth; x++)
                        {

                            p = (int)FrameBuffer[y * 170 + x];
                            r = (p >> 16) & 0xff;
                            g = (p >> 8) & 0xff;
                            b = (p) & 0xff;

                            save_bitmap.SetPixel(x, y, System.Drawing.Color.FromArgb(r, g, b));

                        }
                    }
                    save_bitmap.Save(saveFileDialog.FileName);


                }
            }
            catch
            {

            }

        }
    }
}
