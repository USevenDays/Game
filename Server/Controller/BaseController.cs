﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Common;
using Server.Server;
using System.Net.Sockets;
using Server.Tool;

namespace Server.Controller
{
    public abstract class BaseController
    {
        public abstract OperationCode RequestCode
        {
            get;
        }
    }
}
