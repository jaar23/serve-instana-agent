# Instana agent installation at ease

Using miniserve to serve instana agent installer over http. Ops team then can download the one-liner script and run installation.

![overview](./images/serve-instana.gif)

In a typical air gap environment POC, we are going to deploy Instana Server on a 64gb RHEL and expose port <b>1444</b> for agent connection. We can make use of port <b>1444</b> for agent distribution and install. The overall concept is simple:

1. Temporary shutdown Instana backend server.
2. Bring up miniserve and run the installation command provided in this repo.
3. When all installation is done, shutdown miniserve and bring Instana backend server up again.


### What you need?

1. Download the installer from official package site (package.instana.io), selected static installer rather than dynamic installer as we are working on the air gap environment. Installer for example: 
    - Instana.gpg
    - instana-agent-static-20230215-2008.x86_64.rpm
    - instana-agent-aix-ppc-64bit.tar.gz (from instana console)

2. Move the downloaded file to public folder.

3. Run ```./run-miniserve.sh -u _ -p password -t 8443 -a <agent-key>``` in your instana server host, run-miniserve.sh will help you replace the setup script with  most of the value.

    Miniserve Server will output the following commands for quick installation.
    ```shell
    Run the following command in the managed to server to install instana agent
    RHEL:
    curl -L -o setup-airgap.sh http://_:password@169.38.134.89:8443/setup-airgap.sh && chmod +x setup-airgap.sh && sudo ./setup-airgap.sh --agentkey <agent-key> --host 169.38.134.89

    AIX:
    curl -L -o setup-airgap.ksh http://_:password@169.38.134.89:8443/setup-airgap.ksh && chmod +x setup-airgap.ksh && sudo ./setup-airgap.ksh -i
    miniserve v0.23.0
    Bound to [::]:8443, 0.0.0.0:8443
    Serving path /home/itzuser/file-server/public
    Available at (non-exhaustive list):
        http://10.163.58.48:8443
        http://127.0.0.1:8443
        http://169.38.134.89:8443
        http://172.17.0.1:8443
        http://[::1]:8443

    Quit by pressing CTRL-C

    ```

4. Copy the command provided above and ssh into your manage-to server, then run.
    ```shell
    curl -L -o setup-airgap.sh http://_:password@169.38.134.89:8443/setup-airgap.sh && chmod +x setup-airgap.sh && sudo ./setup-airgap.sh --agentkey <agent-key> --host 169.38.134.89
    ```

That's it! 

You would see instana agent start monitoring your server.

RHEL Server
![rhel](./images/rhel-agent-installation.png)

AIX Server
![aix](./images/aix-agent-installed.png)

You can run ```setup-airgap.sh -h``` to see the available command. For unix host, run ```setup-airgap.ksh -h```.

### Current support platform

- RHEL (rpm), rpm installer now support one-liner installation.
- AIX (unix), aix installer support interactive installation steps.

