﻿// Copyright (c) 2014 hugula
// direct https://github.com/Hugulor/Hugula
//
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
//using ICSharpCode.SharpZipLib.Zip;
using System.Linq;

using Hugula.Utils;
using Hugula.Cryptograph;

namespace Hugula.Editor
{
    public class ExportResources
    {

        public const string ConfigPath = EditorCommon.ConfigPath;//"Assets/Hugula/Config";

        #region osx lua
#if UNITY_IPHONE
    public static string luajit32Path=CurrentRootFolder+"tools/luaTools/luajit2.1";
	public static string luajit64Path=CurrentRootFolder+"tools/luaTools/luajit64";
#elif UNITY_ANDROID && UNITY_EDITOR_OSX
	public static string luajit32Path=CurrentRootFolder+"tools/luaTools/luajit2.1";
    public static string luajit64Path="";
#elif UNITY_ANDROID && UNITY_EDITOR_WIN
        public static string luajit32Path = CurrentRootFolder + "tools/luaTools/win/210/luajit.exe";
        public static string luajit64Path = "";
#elif UNITY_STANDALONE_WIN && UNITY_EDITOR_WIN //pc版本
    public static string luajit32Path = CurrentRootFolder+"tools/luaTools/win/204/luajit.exe";
    public static string luajit64Path="";
#elif UNITY_STANDALONE_WIN && UNITY_EDITOR_OSX //pc版本
	public static string luajit32Path=CurrentRootFolder+"tools/luaTools/luajit2.04";
    public static string luajit64Path = "";
#elif UNITY_STANDALONE_OSX
    public static string luajit32Path=CurrentRootFolder+"tools/luaTools/luac";
    public static string luajit64Path = "";
#else
    public static string luajit32Path = "";
    public static string luajit64Path = "";
#endif

#if UNITY_EDITOR_WIN //win
        public static string luaWorkingPath = CurrentRootFolder + "tools/luaTools/win";
        public static string luacPath = CurrentRootFolder + "tools/luaTools/win/204/luajit.exe";
#elif UNITY_STANDALONE_WIN && UNITY_EDITOR_OSX //win on mac
    public static string luaWorkingPath = CurrentRootFolder+"tools/luaTools";
    public static string luacPath = CurrentRootFolder+"tools/luaTools/luajit2.04";
#else // mac 
    public static string luaWorkingPath = CurrentRootFolder+"tools/luaTools";
    public static string luacPath = CurrentRootFolder+"tools/luaTools/luac";
#endif

#if UNITY_EDITOR_OSX && (UNITY_ANDROID || UNITY_IPHONE)
    public static string OutLuaPath = CurrentRootFolder+"Assets/" + Common.LUACFOLDER + "/osx";
#elif UNITY_EDITOR_OSX && UNITY_STANDALONE_WIN
    public static string OutLuaPath = CurrentRootFolder+"Assets/" + Common.LUACFOLDER + "/win";
#elif UNITY_EDITOR_WIN
        public static string OutLuaPath = CurrentRootFolder + "Assets/" + Common.LUACFOLDER + "/win";
#else //默认平台
    public static string OutLuaPath = CurrentRootFolder+"Assets/" + Common.LUACFOLDER + "/osx";
#endif

    //lua bytes 输出目录
    public static string OutLuaBytesPath = CurrentRootFolder+"Assets/" + Common.LUACFOLDER + "/Resources";

#if UNITY_ANDROID
        public static string LuaTmpPath = "Assets/Tmp/" + Common.LUA_TMP_FOLDER;//"/Tmp/" + Common.LUACFOLDER + "/";
#endif

        public static string CurrentRootFolder
        {
            get
            {
                string dataPath = Application.dataPath;
                dataPath = dataPath.Replace("Assets", "");
                return dataPath;
            }
        }

        #endregion

        #region update
        /// <summary>
        /// Builds the asset bundles update A.
        /// </summary>
        public static void buildAssetBundlesUpdateAB()
        {
            EditorUtility.DisplayProgressBar("Generate FileList", "loading bundle manifest", 1 / 2);
            AssetDatabase.Refresh();
            string readPath = BuildScript.GetFileStreamingOutAssetsPath();// 读取Streaming目录
            var u3dList = getAllChildFiles(readPath, @"\.meta$|\.manifest$|\.DS_Store$|\.u$", null, false);
            List<string> assets = new List<string>();
            foreach (var s in u3dList)
            {
                string ab = GetAssetPath(s); //s.Replace(readPath, "").Replace("/", "").Replace("\\", "");
                assets.Add(ab);
            }

            readPath = BuildScript.GetLuaBytesResourcesPath();// 读取lua 目录
            u3dList = getAllChildFiles(readPath, @"\.bytes$", null);
            foreach (var s in u3dList)
            {
                string ab = GetAssetPath(s); //s.Replace(readPath, "").Replace("/", "").Replace("\\", "");
                assets.Add(ab);
            }

            EditorUtility.ClearProgressBar();
            CUtils.DebugCastTime("Time Generate FileList End");
            Debug.Log("all assetbundle count = " + assets.Count);
            BuildScript.GenerateAssetBundlesUpdateFile(assets.ToArray());
            CUtils.DebugCastTime("Time GenerateAssetBundlesUpdateFile End");
        }

        #endregion


        #region export

        public static void doExportLua(string[] childrens)
        {
             BuildScript.CheckstreamingAssetsPath();

            string info = "luac";
            string title = "build lua";
            EditorUtility.DisplayProgressBar(title, info, 0);

            var checkChildrens = AssetDatabase.GetAllAssetPaths().Where(p =>
                (p.StartsWith("Assets/Lua")
                || p.StartsWith("Assets/Config"))
                && (p.EndsWith(".lua"))
                ).ToArray();
            string path = "Assets/Lua/"; //lua path
            string path1 = "Assets/Config/"; //config path
            string root = CurrentRootFolder;//Application.dataPath.Replace("Assets", "");

            string crypName = "", crypEditorName = "",fileName = "", outfilePath = "", arg = "";
            System.Text.StringBuilder sb = new System.Text.StringBuilder();
            //refresh directory
            if (checkChildrens.Length == childrens.Length) DirectoryDelete(OutLuaPath);
            CheckDirectory(OutLuaPath);

            float allLen = childrens.Length;
            float i = 0;

            System.Diagnostics.Process luaProccess = new System.Diagnostics.Process();
            luaProccess.StartInfo.CreateNoWindow = true;
            luaProccess.StartInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            luaProccess.StartInfo.FileName = luacPath;

            System.Diagnostics.Process luajit32Proccess = new System.Diagnostics.Process();
            luajit32Proccess.StartInfo.CreateNoWindow = true;
            luajit32Proccess.StartInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            luajit32Proccess.StartInfo.FileName = luajit32Path;
            luajit32Proccess.StartInfo.WorkingDirectory = luaWorkingPath;

            System.Diagnostics.Process luajit64Proccess = new System.Diagnostics.Process();
            luajit64Proccess.StartInfo.CreateNoWindow = true;
            luajit64Proccess.StartInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            luajit64Proccess.StartInfo.FileName = luajit64Path;
            luajit64Proccess.StartInfo.WorkingDirectory = luaWorkingPath;

            Debug.Log("luajit32Path:" + luajit32Path);
            Debug.Log("luajit64Path:" + luajit64Path);
            Debug.Log("luacPath:" + luacPath);

            string streamingAssetsPath =  OutLuaBytesPath; //Path.Combine(CurrentRootFolder, LuaTmpPath);
            DirectoryDelete(streamingAssetsPath);
            CheckDirectory(streamingAssetsPath);

            Debug.Log(streamingAssetsPath);
            luaProccess.StartInfo.WorkingDirectory = luaWorkingPath;

            foreach (string file in childrens)
            {
                string filePath = Path.Combine(root, file);
                fileName = CUtils.GetAssetName(filePath);
                crypName = file.Replace(path, "").Replace(path1, "").Replace(".lua", ".bytes").Replace("\\", "+").Replace("/", "+");
                crypEditorName = file.Replace(path, "").Replace(path1, "").Replace(".lua", "."+Common.LUA_LC_SUFFIX).Replace("\\", "+").Replace("/", "+");
                if (!string.IsNullOrEmpty(luajit32Path))// luajit32
                {
                    string override_name = CUtils.GetRightFileName(crypName);
                    string override_lua = Path.Combine(streamingAssetsPath, override_name);
                    arg = "-b " + filePath + " " + override_lua; //for jit
                    // Debug.Log(arg);
                    luajit32Proccess.StartInfo.Arguments = arg;
                    luajit32Proccess.Start();
                    luajit32Proccess.WaitForExit();
                    sb.AppendLine("[\"" + crypName + "\"] = { name = \"" + override_name + "\", path = \"" + file + "\", out path = \"" + override_lua + "\"},");
                }
                if (!string.IsNullOrEmpty(luajit64Path)) //luajit64
                {
                    string crypName_64 = CUtils.InsertAssetBundleName(crypName, "_64");
                    string override_name = CUtils.GetRightFileName(crypName_64);
                    string override_lua = Path.Combine(streamingAssetsPath, override_name);
                    arg = "-b " + filePath + " " + override_lua; //for jit
                    //  Debug.Log(arg);
                    luajit64Proccess.StartInfo.Arguments = arg;
                    luajit64Proccess.Start();
                    luajit64Proccess.WaitForExit();
                    sb.AppendLine("[\"" + crypName_64 + "\"] = { name = \"" + override_name + "\", path = \"" + file + "\", out path = \"" + override_lua + "\"},");
                }
                if (!string.IsNullOrEmpty(luacPath)) //for editor
                {
                    string override_name = CUtils.GetRightFileName(crypEditorName); //CUtils.GetRightFileName(CUtils.InsertAssetBundleName(crypName,"_64"));
                    string override_lua = Path.Combine(OutLuaPath, override_name);
#if UNITY_EDITOR_OSX  && !UNITY_STANDALONE_WIN  
                    arg="-o "+override_lua+" "+filePath; //for lua
#else
                    arg = "-b " + filePath + " " + override_lua; //for jit
#endif
                    // Debug.Log(arg);
                    luaProccess.StartInfo.Arguments = arg;
                    luaProccess.Start();
                    luaProccess.WaitForExit();
                    sb.AppendLine("[\"" + crypEditorName + "(editor)\"] = { name = \"" + override_name + "\", path = \"" + file + "\", out path = \"" + override_lua + "\"},");
                }
                i++;
                EditorUtility.DisplayProgressBar(title, info + "=>" + i.ToString() + "/" + allLen.ToString(), i / allLen);
            }

            Debug.Log("lua:" + path + "files=" + childrens.Length + " completed");
            System.Threading.Thread.Sleep(100);

            //out md5 mapping file
            string tmpPath = BuildScript.GetAssetTmpPath();
            ExportResources.CheckDirectory(tmpPath);
            string outPath = Path.Combine(tmpPath, "lua_md5mapping.txt");
            Debug.Log("write to path=" + outPath);
            using (StreamWriter sr = new StreamWriter(outPath, false))
            {
                sr.Write(sb.ToString());
            }

            EditorUtility.ClearProgressBar();
        }

        public static void exportLua()
        {
             var childrens = AssetDatabase.GetAllAssetPaths().Where(p =>
                (p.StartsWith("Assets/Lua")
                || p.StartsWith("Assets/Config"))
                && (p.EndsWith(".lua"))
                ).ToArray();
           doExportLua(childrens);
        }

        public static void exportConfig()
        {
            var files = AssetDatabase.GetAllAssetPaths().Where(p =>
             p.StartsWith("Assets/Config") || !p.StartsWith("Assets/Config/Lan")
             && p.EndsWith(".csv")
             ).ToArray();

            BuildScript.CheckstreamingAssetsPath();

            if(files.Length>0)
            {
                string cname = CUtils.GetRightFileName(Common.CONFIG_CSV_NAME);
                BuildScript.BuildABs(files.ToArray(), null, cname, BuildAssetBundleOptions.DeterministicAssetBundle);
                Debug.Log(" Config export " + cname);
            }

        }

        public static void exportLanguage()
        {
            var files = AssetDatabase.GetAllAssetPaths().Where(p =>
                p.StartsWith("Assets/Config/Lan")
                && p.EndsWith(".csv")
            ).ToArray();

            BuildScript.CheckstreamingAssetsPath();

            foreach (string abPath in files)
            {
                string name = CUtils.GetAssetName(abPath);
                string abName = CUtils.GetRightFileName(name + Common.CHECK_ASSETBUNDLE_SUFFIX);
                BuildScript.BuildABs(new string[] { abPath }, null, abName, BuildAssetBundleOptions.None);
                Debug.Log(name + " " + abName + " export");
            }
        }

        public static void exportPublish()
        {
            exportLua();
            CUtils.DebugCastTime("Time exportLua End");
            exportLanguage();
            //exportConfig();
            BuildScript.BuildAssetBundles(); //导出资源
            //CleanAssetbundle.Clean();        //清理多余的资源
            CUtils.DebugCastTime("Time BuildAssetBundles End");
            buildAssetBundlesUpdateAB();//更新列表和版本号码
            CUtils.DebugCastTime("Time buildAssetBundlesUpdateAB End");
        }

        #endregion
        

        #region private
        

        public static void DeleteStreamingOutPath()
        {
            ExportResources.DirectoryDelete(Application.streamingAssetsPath);
        }

        public static void CheckDirectory(string fullPath)
        {
            if (!Directory.Exists(fullPath))
            {
                Directory.CreateDirectory(fullPath);
            }
        }

        public static string GetAssetPath(string filePath)
        {
            string path = filePath.Replace(Application.dataPath+"/","");
            return path;//Path.Combine("Assets",path);
        }

        public static List<string> getAllChildFiles(string path, string suffix = "lua", List<string> files = null, bool isMatch = true)
        {
            if (files == null) files = new List<string>();
            if (!string.IsNullOrEmpty(path)) addFiles(path, suffix, files, isMatch);
            string[] dires = Directory.GetDirectories(path);
            foreach (string dirp in dires)
            {
                //            Debug.Log(dirp);
                getAllChildFiles(dirp, suffix, files, isMatch);
            }
            return files;
        }

        public static void addFiles(string direPath, string suffix, List<string> files, bool isMatch = true)
        {
            string[] fileMys = Directory.GetFiles(direPath);
            foreach (string f in fileMys)
            {
                if (System.Text.RegularExpressions.Regex.IsMatch(f, suffix) == isMatch)
                {
                    files.Add(f);
                }
            }
        }

        public static void DirectoryDelete(string path)
        {
            DirectoryInfo di = new DirectoryInfo(path);
            if (di.Exists) di.Delete(true);
        }
        #endregion
    }
}