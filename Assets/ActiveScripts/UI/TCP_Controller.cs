using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using Shapes2D;
using System.Threading;
using TMPro;
using PimDeWitte.UnityMainThreadDispatcher;
public class TCP_Controller : MonoBehaviour
{
    // TCP
    public string serverIP = "192.168.1.1";
    public int port = 5005;
    public TMP_InputField _ip;
    public TMP_InputField _port;
    private TcpClient client;
    private NetworkStream stream;
    private bool connected = false;
    private Thread receiveThread;
    private bool isReceiving = false;
    // Button
    public Button connectButton;
    public Shape targetShape;
    public Texture2D textureBeforeConnect;
    public Texture2D textureAfterConnect;

    // --------- UIパラメータ ---------
    // 両目
    public TMP_InputField Lx;
    public Slider Lx_slider;
    public Toggle Lx_Int;
    public TMP_InputField Ly;
    public Slider Ly_slider;
    public Toggle Ly_Int;
    public TMP_InputField Lz;
    public Slider Lz_slider;
    public Toggle Lz_Int;
    public TMP_InputField Rx;
    public Slider Rx_slider;
    public Toggle Rx_Int;
    public TMP_InputField Ry;
    public Slider Ry_slider;
    public Toggle Ry_Int;
    public TMP_InputField Rz;
    public Slider Rz_slider;
    public Toggle Rz_Int;
    // その他
    public TMP_InputField Picture;
    public Slider Pic_slider;
    public Toggle Pic_Int;
    public TMP_InputField Material;
    public Slider Mat_slider;
    public Toggle Mat_Int;
    public TMP_InputField Origin;
    public Slider Ori_slider;
    public Toggle Ori_Int;
    
    public GameObject UI;

    [Header("Phi Calibration")]
    public TMP_InputField Phi;
    public Slider Phi_slider;
    public Toggle Phi_Int;

    [Header("K Calibration")]
    public TMP_InputField K;
    public Slider K_slider;
    public Toggle K_Int;
    
    void Start()
    {
        connectButton.onClick.AddListener(OnConnectButtonPressed);
        UpdateButtonIcon();
        _ip.text = serverIP;
        _port.text = port.ToString();
    }
    // Connect / Disconnect TCP Server
    public void OnConnectButtonPressed()
    {
        if (!connected)
        {
            try
            {
                client = new TcpClient(serverIP, port);
                stream = client.GetStream();
                connected = true;
                Debug.Log("サーバーに接続しました");
                // 受信スレッド開始
                isReceiving = true;
                receiveThread = new Thread(ReceiveData);
                receiveThread.IsBackground = true;
                receiveThread.Start();
                SendMessageToServer("Hello from 3D-iPad");
                UpdateButtonIcon();
            }
            catch (SocketException e)
            {
                Debug.LogError("接続失敗: " + e.Message);
            }
        }
    }
    // ButtonIconChange
    void UpdateButtonIcon()
    {
        if (targetShape == null) return;
        if (connected)
        {
            targetShape.settings.fillTexture = textureAfterConnect;
        }
        else
        {
            targetShape.settings.fillTexture = textureBeforeConnect;
        }
        targetShape.settings.dirty = true; // 再描画を促す
    }
    // IP change
    public void IPchange()
    {
        serverIP = _ip.text;
    }
    // PORT change
    public void PORTchange()
    {
        port = int.Parse(_port.text);
    }
    // SendCommand
    public void SendMessageToServer(string message)
    {
        if (connected && stream != null)
        {
            byte[] data = Encoding.UTF8.GetBytes(message);
            stream.Write(data, 0, data.Length);
        }
    }
    // Receive Data
    private void ReceiveData()
    {
        byte[] buffer = new byte[1024];
        while (isReceiving && stream != null && stream.CanRead)
        {
            try
            {
                int bytesRead = stream.Read(buffer, 0, buffer.Length);
                if (bytesRead > 0)
                {
                    string received = Encoding.UTF8.GetString(buffer, 0, bytesRead).Trim();
                    Debug.Log("サーバーから受信: " + received);
                    // 現在のパラメータ送信
                    if (received == "request")
                    {
                        Debug.Log("Requestを受信 → パラメータ送信開始");
                        string safe(string input) => string.IsNullOrEmpty(input) ? "0.0" : input;
                        string boolToString(bool b) => b ? "1" : "0";
                        string message = "current/" +
                            safe(Lx.text) + "/" + (Lx_Int.isOn ? "1" : "0") + "/" +
                            safe(Ly.text) + "/" + (Ly_Int.isOn ? "1" : "0") + "/" +
                            safe(Lz.text) + "/" + (Lz_Int.isOn ? "1" : "0") + "/" +
                            safe(Rx.text) + "/" + (Rx_Int.isOn ? "1" : "0") + "/" +
                            safe(Ry.text) + "/" + (Ry_Int.isOn ? "1" : "0") + "/" +
                            safe(Rz.text) + "/" + (Rz_Int.isOn ? "1" : "0") + "/" +
                            safe(Picture.text) + "/" + (Pic_Int.isOn ? "1" : "0") + "/" +
                            safe(Material.text) + "/" + (Mat_Int.isOn ? "1" : "0") + "/" +
                            safe(Origin.text) + "/" + (Ori_Int.isOn ? "1" : "0") + "/" +
                            safe(Phi.text) + "/" + (Phi_Int.isOn ? "1" : "0") + "/" +
                            safe(K.text) + "/" + (K_Int.isOn ? "1" : "0") + "/" +
                            "\n";
                        Debug.Log("送信内容: " + message);
                        SendMessageToServer(message);
                    }
                    // パラメータ更新
                    else if (received.StartsWith("current/"))
                    {
                        ProcessIncomingParams(received);
                    }
                    // ------- クロストーク比実験 -------
                    // * 先に "wb" or "bw" を判断しないといけない
                    // 白黒
                    else if (received.StartsWith("wb"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() => { Pic_slider.value = 4; });
                        SendMessageToServer("ACK\n");
                    }
                    // 黒白
                    else if (received.StartsWith("bw"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() => { Pic_slider.value = 5; });
                        SendMessageToServer("ACK\n");
                    }
                    // 黒
                    else if (received.StartsWith("b"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() => { Pic_slider.value = 2; });
                        SendMessageToServer("ACK\n");
                    }
                    // 白
                    else if (received.StartsWith("w"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() => { Pic_slider.value = 3; });
                        SendMessageToServer("ACK\n");
                    }
                    // アイトラッキング(水平)
                    else if (received.StartsWith("EyeTracking_Horizontal"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() =>
                        {
                            Lx_slider.value += 1;
                            Rx_slider.value += 1;
                        });
                        SendMessageToServer("ACK\n");
                    }
                    // アイトラッキング(奥行)
                    else if (received.StartsWith("EyeTracking_Depth"))
                    {
                        UnityMainThreadDispatcher.Instance().Enqueue(() =>
                        {
                            Lz_slider.value += 1;
                            Rz_slider.value += 1;
                        });
                        SendMessageToServer("ACK\n");
                    }
                    // 他のコマンド
                    else
                    {
                        Debug.Log("未定義のメッセージ: " + received);
                    }
                }
            }
            catch (IOException e)
            {
                Debug.LogWarning("受信中にエラーが発生: " + e.Message);
                break;
            }
        }
        isReceiving = false;
        connected = false;
        UpdateButtonIcon();
    }
    // パラメータ更新処理
    private void ProcessIncomingParams(string received)
    {
        string[] tokens = received.Split(new char[] { '/' }, StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Length >= 22 && tokens[0] == "current")
        {
            // Debug.Log("受信パラメータ数: " + tokens.Length);
            // 受信した値でUIを更新
            // Debug.Log($"UI = {tokens[25]}");
            // Debug.Log($"Lx = {tokens[1]}, Lx_Int = {tokens[2]}");
            // Debug.Log($"Ly = {tokens[3]}, Ly_Int = {tokens[4]}");
            // Debug.Log($"Lz = {tokens[5]}, Lz_Int = {tokens[6]}");
            // Debug.Log($"Rx = {tokens[7]}, Rx_Int = {tokens[8]}");
            // Debug.Log($"Ry = {tokens[9]}, Ry_Int = {tokens[10]}");
            // Debug.Log($"Rz = {tokens[11]}, Rz_Int = {tokens[12]}");
            // Debug.Log($"Pic = {tokens[13]}, Pic_Int = {tokens[14]}");
            // Debug.Log($"Mat = {tokens[15]}, Mat_Int = {tokens[16]}");
            // Debug.Log($"Ori = {tokens[17]}, Ori_Int = {tokens[18]}");
            // Debug.Log($"OnDotNum = {tokens[19]}, OnDotNums_Int = {tokens[20]}");
            // UI更新したい場合は Unity のメインスレッドで実行する必要がある
            UnityMainThreadDispatcher.Instance().Enqueue(() =>
            {
                Lx_slider.value = float.Parse(tokens[1]);
                Lx_Int.isOn = tokens[2] == "1";
                Ly_slider.value = float.Parse(tokens[3]);
                Ly_Int.isOn = tokens[4] == "1";
                Lz_slider.value = float.Parse(tokens[5]);
                Lz_Int.isOn = tokens[6] == "1";
                Rx_slider.value = float.Parse(tokens[7]);
                Rx_Int.isOn = tokens[8] == "1";
                Ry_slider.value = float.Parse(tokens[9]);
                Ry_Int.isOn = tokens[10] == "1";
                Rz_slider.value = float.Parse(tokens[11]);
                Rz_Int.isOn = tokens[12] == "1";
                Pic_slider.value = float.Parse(tokens[13]);
                Pic_Int.isOn = tokens[14] == "1";
                Mat_slider.value = float.Parse(tokens[15]);
                Mat_Int.isOn = tokens[16] == "1";
                Ori_slider.value = float.Parse(tokens[17]);
                Ori_Int.isOn = tokens[18] == "1";
                Phi_slider.value = float.Parse(tokens[19]);
                Phi_Int.isOn = tokens[20] == "1";
                K_slider.value = float.Parse(tokens[21]);
                K_Int.isOn = tokens[22] == "1";
                UI.SetActive(tokens[23] == "1");
            });
        }
        else
        {
            Debug.LogWarning("受信データ形式が不正です: " + received);
        }
    }
    void OnApplicationQuit()
    {
        isReceiving = false;
        receiveThread?.Join();
        stream?.Close();
        client?.Close();
        connected = false;
        UpdateButtonIcon();
    }
}
