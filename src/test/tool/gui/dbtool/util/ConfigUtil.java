package test.tool.gui.dbtool.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.Hashtable;
import org.apache.log4j.Logger;

import test.tool.gui.common.SysFontAndFace;
import test.tool.gui.dbtool.consts.Const;

public class ConfigUtil {
	
	private static Logger log = Logger.getLogger(ConfigUtil.class);

	/*
	 * 获取配置信息
	 */
	private static Hashtable<String,Object> conf_table = null;
	public static Hashtable<String,Object> getConfInfo(){
		if(conf_table==null){
			conf_table = loadConfInfo();
		}
		return conf_table;
	}
	/*
	 * 更新配置文件，config/conf.data
	 */
	public static void updateConfInfo(){

		ObjectOutputStream oops = null;
		try {
			oops = new ObjectOutputStream(new FileOutputStream(Const.CONF_PATH));
			oops.writeObject(getConfInfo());
		} catch (Exception e) {
			log.error("更新配置文件出错！",e);
			throw new RuntimeException("更新配置文件出错！",e);
		}finally{
			if(oops!=null){			
				try {
					oops.flush();
					oops.close();
				} catch (IOException e) {log.error(null, e);}
			}
		}
	}
	/*
	 * 读取配置文件，config/conf.data
	 */
	private static Hashtable<String,Object> loadConfInfo(){
		ObjectInputStream oips = null;
		try {
			File file = new File(Const.CONF_PATH);
			if(file.exists()){		
				oips = new ObjectInputStream(new FileInputStream(file));
				conf_table=(Hashtable<String,Object>)oips.readObject();
			}
		} catch (Exception e) {
			log.error("读取配置文件出错！",e);
			throw new RuntimeException("读取配置文件出错！",e);
		}finally{
			if(oips!=null)
				try {
					oips.close();
				} catch (IOException e) {log.error(null, e);}
		}
		 //首次使用本软件时，conf_table为null
		if (conf_table == null) {
			conf_table = new Hashtable<String, Object>();
		}
		// 眼睛保护色（默认是绿豆沙）
		if(conf_table.get(Const.EYE_SAFETY_COLOR)==null){
			conf_table.put(Const.EYE_SAFETY_COLOR,ColorUtil.getColor("绿豆沙"));
			updateConfInfo();
		}
		//设置默认字体
		if(conf_table.get(Const.FONT)==null){
			conf_table.put(Const.FONT,SysFontAndFace.font15);
			updateConfInfo();
		}
		return conf_table;
	}
}
