Installing Open-WebUI and Ollama on Apple Silicon (without Docker)
-

&nbsp;&nbsp;&nbsp;

If you want to learn Open-WebUI, how it works, or you want to set up a server for more than one computer on your network to access or you want maximum performance (because running Ollama in Docker for Mac doesn't use your GPU) then follow this guide. This was tested on MacOS Tahoe 26.4.1

> NOTE: After Installation use the included update script to update both Ollama and Open-WebUI to the latest available versions online.

&nbsp;&nbsp;&nbsp;

Open up a Terminal window, and paste in the following commands, one at a time, and wait for each step to finish:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install ollama pipx

pipx install open-webui --python 3.12
```  

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;


Then, start ollama in that window by typing

    brew services start ollama 

then type

    open-webui serve  
    
Single Command to start Ollama and start Open Webui:

    brew services start ollama && open-webui serve

If you receive error, scroll down to see solution.  

&nbsp;&nbsp;&nbsp;&nbsp;

You should see "OpenWebUI" in large text within the terminal window if successfull. In my experience, both windows have to be open separately for both to run, but start Ollama first. You can minimize both windows at this point while you're running Open WebUI. 

Then open a web browser and go to http://localhost:8080 and create your first account, the admin account.

**Downloading Models:** Then you can, within OWUI, go to Admin Settings, Settings, Models, and click the "download" icon in the upper right that says "Manage Models" when you hover over it. Go to the Ollama Models page in a separate tab, and copy links to whatever model you want to download, and you can paste it in the dialog box, click download on the right, and wait for it to finish. Refresh your main page when all done, and it'll show up in the upper left.

**About Your Mac's GPU RAM (VRAM):** One of Apple Silicon's advantages is Unified Memory - system RAM is also GPU RAM, so there's no delay copying data to main memory, and then to GPU memory, like on PCs. This will run with best performance if your GPU runs as much as possible inside of its allocated memory, or VRAM.

Your GPU VRAM maximum allocation is usually 75% of total RAM, but this can be tweaked. Leave enough RAM (6GB or so) for your OS. Be careful to not try to run any model that comes even close to your VRAM limit, or things will slow down - a lot. Larger context windows use more RAM.

**Quitting Running Components & Updating:** To terminate all running processes, just quit Terminal. Your Mac will verify that you want to terminate both running apps - just click "terminate processes" and OpenWebUI is off until you reopen terminal windows again and start up both components. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

Upgrade Open WebUI and Ollama:
-

To upgrade to latest versions of Ollama:

    brew upgrade ollama

To upgrade to latest version of Open WebUI:

    pipx upgrade open-webui

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;


Problem running command `open-webui serve`
-

On my Mac (Tahoe 26.4.1) after 

    pipx install --fetch-python=missing --python 3.11 open-webui --force

then

    pipx ensurepath


(ignore the bashrc suggestion, MacOS uses zsh) 

and then closed/reopened Terminal and it works! 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

Advanced Tip - Running Open WebUI in the background
-
If you want to start both Ollama and Open WebUI in the background, and not need to keep the Terminal window open, then you can use the following command:

    brew services restart ollama && nohup open-webui serve &>/tmp/open-webui.log &

This will start (or restart if ollama is already running) both applications in the background. The log file in /tmp/ will show the output from Open WebUI.

To stop Open WebUI starting this method you will need to use the following command:

    pkill -f "open-webui" 1>/dev/null
    
To terminate Ollama

    brew services stop ollama

to restart Ollama (stop and start)

    brew services restart ollama

and to stop both Ollama and Open WebUI, use the following:

    brew services stop ollama && pkill -f "open-webui" 1>/dev/null

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

Display the Local IPv4 Address on your Mac: 
-

via Terminal (Fastest)Open Terminal (press Cmd + Space, type "Terminal", hit Enter)
For Wi-Fi, type: 

    ipconfig getifaddr en0

For Ethernet, type: 

    ipconfig getifaddr en1

Hit Enter to display the IP address


&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

<sub>Credits: Based on my personal installation and setup, with the guidance of the excellent article posted on Reddit by u/BringOutYaThrowaway - https://www.reddit.com/r/OpenWebUI/comments/1mfq0es/installing_openwebui_on_apple_silicon_without/</sub>

