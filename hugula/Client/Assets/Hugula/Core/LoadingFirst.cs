﻿using UnityEngine;
using Hugula.Loader;
using Hugula.Utils;

public class LoadingFirst : MonoBehaviour {
	
	public string sceneName = "begin";
	public string sceneAssetBundleName = "begin.u3d";
	// Use this for initialization
	void Start () {
		//load manifest
		CUtils.DebugCastTime("LoadingFirst");
		Hugula.Localization.language = PlayerPrefs.GetString ("Language", Application.systemLanguage.ToString());
		LoadFirstHelper.LoadManifest(sceneAssetBundleName,sceneName);
	}

}


public class LoadFirstHelper
{
	public static string sceneAssetBundleName;
	public static string sceneName;
	public static void LoadManifest(string sceneAbName,string scenename)
	{
		sceneAssetBundleName = sceneAbName;
		sceneName = scenename;
        

		#if UNITY_EDITOR
		Debug.LogFormat("<color=green>SimulateAssetBundleInEditor {0} mode </color> <color=#8cacbc> change( menu AssetBundles/Simulation Mode)</color>", CResLoader.SimulateAssetBundleInEditor ? "simulate" : "assetbundle");
		if(CResLoader.SimulateAssetBundleInEditor)
		{
			BeginLoadScene();
			return;
		}
		#endif
		var  url = CUtils.GetPlatformFolderForAssetBundles();
		var req = LRequest.Get();
		req.relativeUrl = CUtils.GetRightFileName(url);
		req.assetType = typeof(AssetBundleManifest);
		req.assetName = "assetbundlemanifest";
		req.OnComplete = (CRequest req1)=>
		{
			LResLoader.assetBundleManifest=req1.data as AssetBundleManifest;
			#if HUGULA_LOADER_DEBUG 
			Debug.LogFormat("assetbundlemanifest {0} is done !",req1.url);
			#endif
			BeginLoadScene();
		};
		req.OnEnd = (CRequest req1)=>{BeginLoadScene();};
		req.async = true;
		req.isAssetBundle = true;
		LResLoader.instance.OnSharedComplete+=OnSharedComplete;
		LResLoader.instance.LoadReq(req);
	}
	public static void BeginLoadScene()
	{
		CUtils.DebugCastTime("LoadingFirst");
		var req = LRequest.Get();
		req.relativeUrl = CUtils.GetRightFileName(sceneAssetBundleName);
		req.assetName = sceneName;
		req.OnComplete = OnSceneAbLoaded;
		req.OnEnd = OnSceneAbError;
		req.assetType = CacheManager.Typeof_ABScene;
		req.async = true;
		LResLoader.instance.LoadReq(req);
	}

	static void OnSharedComplete(CRequest req) // repaire IOS crash bug when scene assetbundle denpendency sprite atlas assetbundle
	{
		AssetBundle ab = req.data as AssetBundle;
		if(ab)ab.LoadAllAssets();
	}

	static void OnSceneAbLoaded(CRequest req)
	{
		LResLoader.instance.OnSharedComplete-=OnSharedComplete;
		#if HUGULA_LOADER_DEBUG 
		Debug.LogFormat("OnSceneAbLoaded {0} is done !",req.url);
		#endif
		CUtils.DebugCastTime("On "+ sceneName +"Loaded");
	}

	static void OnSceneAbError(CRequest req)
	{
		#if UNITY_EDITOR 
		Debug.LogFormat("OnSceneAbLoaded {0} is Fail !",req.url);
		#endif
		// BeginLoadScene();
	}

}