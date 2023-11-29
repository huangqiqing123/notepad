package test.tool.gui.dbtool;

import java.awt.SplashScreen;
import java.io.File;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Timer;
import java.util.TimerTask;

import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;

import org.apache.log4j.Logger;
import test.tool.gui.common.SysFontAndFace;
import test.tool.gui.dbtool.frame.MyNotePad;

public class Index {

	/*
	 * 程序入口
	 */
	public static void main(String args[]) {

		final String[] filePathArray = args;
		
		//设定端口、IP
		final String ip = "127.0.0.1";
		final int port = 12530;

		ObjectOutputStream out = null;
		Socket socket = null;
		try {
			//检测记事本程序是否已启动，如果已启动，则由已启动的记事本程序来新建或打开文档，如果未启动，则启动记事本程序，并启动监听。
			//连接本机指定端口，如果连接失败（表现形式，抛Connect异常），则说明记事本程序尚未启动。
			socket = new Socket(ip,port);
			out = new ObjectOutputStream(socket.getOutputStream());
           
			//通知运行中的记事本应用，根据传参打开指定文档
        	if(filePathArray != null && filePathArray.length > 0){
        		out.writeObject(filePathArray);
        	
        	//通知运行中的记事本应用，新建空白文档
        	}else{
        		out.writeObject("new");
        	}
        	SplashScreen ss = SplashScreen.getSplashScreen();
    		if (ss != null) {
    			ss.close();
    		}
        	//退出java虚拟机
        	System.exit(0);
        
		} catch (Exception e) {
			//-----------抛异常说明记事本程序尚未启动-------------
			
			// 1、================验证应用程序同级目录下，config文件夹是否存在，如果不存在，则创建。================
			File file_config = new File(System.getenv("TEMP")+"/config");
			if (!file_config.exists() || !file_config.isDirectory()) {
				if (!file_config.mkdirs()) {
					JOptionPane.showMessageDialog(null, "创建config目录失败！");
					System.exit(0);
				}
			}
        	//2、================新启线程，监听socket连接================
			new Thread(){
				@Override
				public void run() {
					ObjectInputStream serverIn = null;
					Socket clientSocket = null;
					try {
						ServerSocket serverSocket = new ServerSocket(port);
						while(true){
							//accept()会阻塞当前线程的继续执行，当有新客户端接入，才会向下运行。
							clientSocket = serverSocket.accept();
							serverIn = new ObjectInputStream(clientSocket.getInputStream());
							
							//取得客户端发送的数据
		            		final Object getMsg = serverIn.readObject();
		            		 
		            		//每个记事本启动时，只会向服务器端发一条信息（new 或 要打开文档的地址），所以处理完请求则关闭相应资源。
			                try {
								 serverIn.close();
							} catch (IOException e) {
								e.printStackTrace();
							}
							try {
								clientSocket.close();
							} catch (Exception e) {
								e.printStackTrace();
							}
		            		
		            		//如果客户端发送的信息是 new ，则新建空白文档
			                if(getMsg.toString().equals("new")){
			                	SwingUtilities.invokeLater(new Runnable(){
									@Override
									public void run() {
										MyNotePad note = new MyNotePad(null, null, null);
										note.setVisible(true);
									}
			                	});
			                }else{
			                	//否则，根据客户端发送过来的路径，打开指定文档。
			                	SwingUtilities.invokeLater(new Runnable(){
									@Override
									public void run() {
										String[] files = (String[])getMsg;
					                	for(int i=0;i<files.length;i++){
					                		MyNotePad note = new MyNotePad(null, null,files[i]);
					                		note.setVisible(true);
					                	}
									}
			                	});
			                }
						}
					} catch (Exception e2) {
						e2.printStackTrace();
					}
				}
			}.start();
		}

		//3、================启动记事本程序================
		// 设置系统字体
		SysFontAndFace.setSysFontAndFace();

		// 设置输入中文时，不显示输入框
		System.setProperty("java.awt.im.style", "on-the-spot");

		try {
			//打开指定路径的文档
			if (filePathArray != null && filePathArray.length > 0) {
				SwingUtilities.invokeAndWait(new Runnable(){
					@Override
					public void run() {
						for (int i = 0; i < filePathArray.length; i++) {
							MyNotePad note = new MyNotePad(null, null,filePathArray[i]);
							note.setVisible(true);
						}
					}
	        	});
			// 打开空白文档
			} else {
				SwingUtilities.invokeAndWait(new Runnable(){
					@Override
					public void run() {
						MyNotePad note = new MyNotePad(null, null, null);
						note.setVisible(true);
					}
	        	});
			}
		} catch (Exception e) {
			JOptionPane.showMessageDialog(null, "出错了，请重新启动！");
			System.exit(1);
		}
		
		//4、================启动定时任务，负责执行gc================
		//创建定时器，一分钟后开始执行，以后每分钟执行一次。
		Timer timer = new Timer();
		timer.schedule(new TimerTask(){
			@Override
			public void run() {
				System.gc() ;
			}
			
		}, 60*1000,60*1000);

		// 5、================关闭欢迎信息================
		SplashScreen ss = SplashScreen.getSplashScreen();
		if (ss != null) {
			ss.close();
		}
	
	}
}
