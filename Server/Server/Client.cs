﻿using Server.Tool;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using Common;
using Server.Controller;

namespace Server.Server
{
    public class Client
    {
        private Socket clientSocket;
        private Server server;
        private string ip;
        private int port;
        private Message msg;

        public Client(Socket clientSocket, Server server)
        {
            this.clientSocket = clientSocket;
            this.server = server;
            this.ip = ((IPEndPoint)clientSocket.RemoteEndPoint).Address.ToString();
            this.port = ((IPEndPoint)clientSocket.RemoteEndPoint).Port;
            this.msg = new Message();
            Message m = new Message();
            m.WriteString("connect success!");
            m.EndWrite();
            clientSocket.Send(m.Buffer, m.EndIndex, SocketFlags.None);
        }

        public void Start()
        {
            clientSocket.BeginReceive(msg.Buffer, msg.EndIndex, msg.Remain, SocketFlags.None, ReceiveAsyncCallback, null);
        }

        private void ReceiveAsyncCallback(IAsyncResult ar)
        {
            try
            {
                int count = clientSocket.EndReceive(ar);
                if (count == 0)
                {
                    Close();
                }
                msg.UpdateEndIndex(count);
                while (msg.Check())
                {
                    //Console.WriteLine("{0}, {1}, {2}", msg.ReadString(), msg.ReadInt(), msg.ReadBool());
                    RequestCode requestCode = (RequestCode)msg.ReadInt();
                    ActionCode actionCode = (ActionCode)msg.ReadInt();
                    string data = msg.ReadString();
                    BaseController bc = ControllerManager.Instance.GetController(requestCode);
                    if (bc == null)
                    {
                        throw (new Exception("controller not found RequestCode is " + requestCode));
                    }
                    bc.HandleMessage(actionCode, new Message(msg), clientSocket, server);
                }
                if (clientSocket != null) Start();
            }
            catch (Exception e)
            {
                Console.WriteLine("client {0}:{1} is disconnected!\n{2}", ip, port, e);
                Close();
            }
        }

        private void Close()
        {
            if (clientSocket != null) clientSocket.Close();
            string key = Util.GetClientKey(ip, port);
            server.RemoveClient(key);
        }
    }
}
